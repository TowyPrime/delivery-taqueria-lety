import { setGlobalOptions } from "firebase-functions";
import { onCall, onRequest, HttpsError } from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import Stripe from "stripe";
import { onSchedule } from "firebase-functions/scheduler";
import { onDocumentUpdated } from "firebase-functions/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
setGlobalOptions({ maxInstances: 10 });

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const geocodingKey = defineSecret("GEOCODING_API_KEY");
const db = getFirestore();
const ENVIO = 10;

interface LineaProducto {
  productId: string;
  quantity: number;
}

interface LineaCarrito {
  type: "individual" | "plato";
  quantity: number;
  productId?: string; // solo individual
  products?: LineaProducto[]; // solo plato
}

function idValido(id: unknown): string {
  if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) {
    throw new HttpsError("invalid-argument", "Producto inválido");
  }
  return id;
}

function cantidadValida(n: unknown): number {
  if (typeof n !== "number" || !Number.isInteger(n) || n < 1 || n > 100) {
    throw new HttpsError("invalid-argument", "Cantidad inválida");
  }
  return n;
}

function distanciaKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371;
  const rad = (g: number) => (g * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

async function geocodificar(
  dir: Record<string, unknown>,
  apiKey: string,
): Promise<{ lat: number; lng: number } | null> {
  const campo = (k: string) => String(dir[k] ?? "").trim();
  const direccion = [
    `${campo("calle")} ${campo("numero_exterior")}`.trim(),
    campo("colonia"),
    campo("codigo_postal"),
    campo("ciudad"),
    "México",
  ]
    .filter(Boolean)
    .join(", ");

  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("address", direccion);
  url.searchParams.set("components", "country:MX");
  url.searchParams.set("key", apiKey);

  try {
    const res = await fetch(url);
    if (!res.ok) {
      logger.warn("Geocoding HTTP", { status: res.status });
      return null;
    }

    const body = (await res.json()) as {
      status: string;
      results: { geometry: { location: { lat: number; lng: number } } }[];
    };

    if (body.status !== "OK") {
      logger.warn("Geocoding sin resultado", { status: body.status });
      return null;
    }

    if (body.results.length === 0) return null;

    return body.results[0].geometry.location;
  } catch (error) {
    logger.error(error);
    return null;
  }
}

export const createCheckout = onCall(
  { secrets: [stripeSecret, geocodingKey] },
  async (request) => {
    // 1. Solo usuarios con cuenta (no invitados)
    const uid = request.auth?.uid;
    if (!uid || request.auth?.token.firebase.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Inicia sesión para pedir");
    }

    // 2. Validar lo que manda la app: solo ids y cantidades, nunca precios
    const lineas = request.data?.items as LineaCarrito[] | undefined;
    if (!Array.isArray(lineas) || lineas.length === 0 || lineas.length > 50) {
      throw new HttpsError("invalid-argument", "Carrito inválido");
    }

    const ids = new Set<string>();
    for (const l of lineas) {
      if (l.type === "individual") {
        ids.add(idValido(l.productId));
      } else if (l.type === "plato" && Array.isArray(l.products)) {
        l.products.forEach((p) => ids.add(idValido(p.productId)));
      } else {
        throw new HttpsError("invalid-argument", "Línea inválida");
      }
    }

    // 3. Precios reales desde Firestore
    const snaps = await db.getAll(
      ...[...ids].map((id) => db.collection("products").doc(id)),
    );
    const catalogo = new Map<
      string,
      { name: string; price: number; contents: string[] }
    >();

    for (const s of snaps) {
      if (!s.exists) {
        throw new HttpsError("not-found", "Un producto ya no está disponible");
      }
      const crudo = s.get("contents");
      catalogo.set(s.id, {
        name: s.get("name"),
        price: Number(s.get("price")),
        contents: Array.isArray(crudo)
          ? crudo.filter((c): c is string => typeof c === "string").slice(0, 20)
          : [],
      });
    }

    let numPlato = 0;
    const items = lineas.map((l) => {
      const quantity = cantidadValida(l.quantity);

      if (l.type === "individual") {
        const p = catalogo.get(l.productId as string)!;
        return {
          type: "individual",
          productId: l.productId,
          name: p.name,
          price: p.price,
          quantity,
          subtotal: p.price * quantity,
          ...(p.contents.length > 0 && { contents: p.contents }),
        };
      }

      numPlato++;
      const products = (l.products as LineaProducto[]).map((sp) => {
        const p = catalogo.get(sp.productId)!;
        return {
          productId: sp.productId,
          name: p.name,
          price: p.price,
          quantity: cantidadValida(sp.quantity),
        };
      });
      const price = products.reduce((t, p) => t + p.price * p.quantity, 0);
      return {
        type: "plato",
        plateId: `plate_${numPlato}`,
        name: `Plato ${numPlato}`,
        price,
        quantity,
        subtotal: price * quantity,
        products: products.map(({ productId, name, quantity: q }) => ({
          productId,
          name,
          quantity: q,
        })),
      };
    });

    // 4. Dirección y zona de reparto, validadas en el servidor
    const user = (await db.collection("users").doc(uid).get()).data();
    const dir = user?.direccion;
    if (!dir || !String(dir.calle ?? "").trim()) {
      throw new HttpsError(
        "failed-precondition",
        "Falta tu dirección de envío",
      );
    }
    const coords = await geocodificar(dir, geocodingKey.value());
    if (coords == null) {
      throw new HttpsError(
        "failed-precondition",
        "No pudimos ubicar tu dirección. Revísala en Mis datos",
      );
    }
    const cfg = (await db.collection("config").doc("delivery").get()).data();
    if (!cfg) {
      throw new HttpsError("internal", "Falta la configuración de reparto");
    }
    const km = distanciaKm(cfg.lat, cfg.lng, coords.lat, coords.lng);
    if (km > cfg.radius_km) {
      throw new HttpsError(
        "failed-precondition",
        `Tu dirección queda a ${km.toFixed(1)} km, fuera de la zona de reparto`,
      );
    }
    const stripe = new Stripe(stripeSecret.value());
    // Limpiar intentos de pago abandonados de este usuario
    const previos = await db
      .collection("orders")
      .where("userId", "==", uid)
      .where("status", "==", "pendiente_pago")
      .get();

    if (!previos.empty) {
      for (const previo of previos.docs) {
        const piId = previo.get("paymentIntentId") as string | undefined;
        try {
          if (piId) await stripe.paymentIntents.cancel(piId);
        } catch (e) {
          const pi = piId ? await stripe.paymentIntents.retrieve(piId) : null;
          if (pi?.status === "succeeded") {
            throw new HttpsError(
              "failed-precondition",
              "Tu pago anterior se está procesando. Espera un momento.",
            );
          }
          if (pi && pi.status !== "canceled") {
            logger.error("No se pudo cancelar el PaymentIntent", { piId, e });
            throw new HttpsError(
              "internal",
              "No pudimos preparar tu pedido. Inténtalo de nuevo.",
            );
          }
        }
        await previo.ref.delete();
      }
    }
    // 5. Totales y cobro
    const subtotal = items.reduce((t, i) => t + i.subtotal, 0);
    const total = subtotal + ENVIO;

    const orderRef = db.collection("orders").doc();
    const intent = await stripe.paymentIntents.create(
      {
        amount: Math.round(total * 100), // Stripe usa centavos
        currency: "mxn",
        automatic_payment_methods: { enabled: true },
        metadata: { orderId: orderRef.id, userId: uid },
      },
      { idempotencyKey: `checkout_${orderRef.id}` },
    );

    // 6. El pedido existe desde ya, pero sin pagar
    const userName =
      `${user?.nombre ?? ""} ${user?.apellido ?? ""}`.trim() ||
      request.auth?.token.email ||
      "cliente";

    await orderRef.set({
      userId: uid,
      userName,
      items,
      subtotal,
      envio: ENVIO,
      total,
      direccion: { ...dir, lat: coords.lat, lng: coords.lng },
      status: "pendiente_pago",
      paymentIntentId: intent.id,
      hasClaim: false,
      claimId: null,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      orderId: orderRef.id,
      clientSecret: intent.client_secret,
      subtotal,
      envio: ENVIO,
      total,
    };
  },
);

export const stripeWebhook = onRequest(
  { secrets: [stripeSecret, stripeWebhookSecret] },
  async (req, res) => {
    const stripe = new Stripe(stripeSecret.value());

    // 1. Comprobar que el aviso viene realmente de Stripe
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        req.headers["stripe-signature"] as string,
        stripeWebhookSecret.value(),
      );
    } catch (e) {
      logger.warn("Firma de webhook inválida", e);
      res.status(400).send("Firma inválida");
      return;
    }

    // 2. Pago exitoso: el pedido pasa de pendiente_pago a pendiente
    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const orderId = pi.metadata.orderId;
      if (!orderId) {
        res.json({ received: true });
        return;
      }

      const ref = db.collection("orders").doc(orderId);
      let reembolsar = false;

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const order = snap.data()!;

        // El cobro debe corresponder a este pedido y a este monto
        if (order.paymentIntentId !== pi.id) return;
        if (pi.amount !== Math.round(order.total * 100)) {
          logger.error("Monto no coincide", { orderId, amount: pi.amount });
          return;
        }

        if (order.status === "pendiente_pago") {
          tx.update(ref, {
            status: "pendiente",
            paidAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else if (order.status === "cancelado") {
          reembolsar = true; // el cliente canceló antes de que llegara el pago
        }
      });

      if (reembolsar) {
        await stripe.refunds.create({ payment_intent: pi.id });
        logger.info("Pedido cancelado y pagado: reembolso emitido", {
          orderId,
        });
      }
    }

    res.json({ received: true });
  },
);

export const cleanupUnpaidOrders = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "America/Mexico_City",
    secrets: [stripeSecret],
  },
  async () => {
    const stripe = new Stripe(stripeSecret.value());
    const limite = Date.now() - 60 * 60 * 1000; //1 hora

    const snap = await db
      .collection("orders")
      .where("status", "==", "pendiente_pago")
      .limit(200)
      .get();

    for (const doc of snap.docs) {
      const order = doc.data();
      const creado = order.createdAt?.toMillis?.() ?? 0;
      if (creado > limite) continue; //Todavia a tiempo de pagar

      try {
        await stripe.paymentIntents.cancel(order.paymentIntentId);
      } catch (e) {
        logger.warn("No se pudo cancelar el PaymentIntent", { id: doc.id, e });
      }

      await doc.ref.update({
        status: "cancelado",
        cancelReason: "pago_no_completado",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  },
);

export const cancelOrder = onCall(
  { secrets: [stripeSecret] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Inicia sesión");
    const orderId = idValido(request.data?.orderId);
    const ref = db.collection("orders").doc(orderId);

    const { paymentIntentId, pagado } = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const order = snap.data();
      if (!order || order.userId !== uid) {
        throw new HttpsError("not-found", "Pedido no encontrado");
      }
      if (!["pendiente_pago", "pendiente"].includes(order.status)) {
        throw new HttpsError(
          "failed-precondition",
          "Tu pedido ya está en preparación y no puede cancelarse",
        );
      }
      const pagado = order.status === "pendiente";
      tx.update(ref, {
        status: "cancelado",
        cancelReason: "cancelado_por_cliente",
        refundStatus: pagado ? "pendiente" : "no_aplica",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { paymentIntentId: order.paymentIntentId as string, pagado };
    });
    const stripe = new Stripe(stripeSecret.value());
    try {
      if (pagado && paymentIntentId) {
        const refund = await stripe.refunds.create(
          { payment_intent: paymentIntentId },
          { idempotencyKey: `refund_${orderId}` },
        );
        await ref.update({
          refundStatus: "emitido",
          refundId: refund.id,
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (paymentIntentId) {
        await stripe.paymentIntents.cancel(paymentIntentId);
      }
    } catch (e) {
      logger.error("Error en Stripe al cancelar/reembolsar", { orderId, e });
      await ref.update({
        refundStatus: "error",
        updatedAt: FieldValue.serverTimestamp(),
      });
      throw new HttpsError(
        "internal",
        "Cancelamos tu pedido, pero el reembolso requiere revisión. Contáctanos.",
      );
    }
    return { refunded: pagado };
  },
);

const MENSAJES_ESTADO: Record<string, string> = {
  pendiente: "Recibimos tu pedido. En breve lo preparamos.",
  preparando: "Tu pedido ya se está preparando.",
  "en preparación": "Tu pedido ya se está preparando.",
  "en camino": "¡Tu pedido va en camino!",
  entregado: "Tu pedido fue entregado. ¡Buen provecho!",
  cancelado: "Tu pedido fue cancelado. Contáctanos si tienes dudas.",
};

export const notifyOrderStatus = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues || antes.status === despues.status) return;

    const orderId = event.params.orderId;
    logger.info("Cambio de estado", {
      orderId,
      de: antes.status,
      a: despues.status,
    });

    const body = MENSAJES_ESTADO[despues.status as string];
    if (!body) {
      logger.info("Sin push: estado sin mensaje", { orderId });
      return; // p. ej. pendiente_pago: no se avisa
    }

    // Cancelaciones que el propio cliente o la limpieza provocaron: sin push
    if (
      despues.status === "cancelado" &&
      ["cancelado_por_cliente", "pago_no_completado"].includes(despues.cancelReason)
    ) {
      logger.info("Sin push: cancelación del cliente o limpieza", { orderId });
      return;
    }

    const tokensRef = db.collection("users").doc(despues.userId).collection("fcmTokens");
    const tokens = (await tokensRef.get()).docs.map((d) => d.id);
    if (tokens.length === 0) {
      logger.warn("Sin push: el usuario no tiene tokens", {
        orderId,
        userId: despues.userId,
      });
      return;
    }

    const res = await getMessaging().sendEach(
      tokens.map((token) => ({
        token,
        notification: { title: "Taquería Lety", body },
        data: { orderId: event.params.orderId, status: despues.status },
        android: { notification: { channelId: "order_channel_id" } },
      })),
    );

    logger.info("Resultado del envío", {
      orderId,
      enviados: res.successCount,
      fallidos: res.failureCount,
      errores: res.responses.map((r) => r.error?.code ?? null),
    });

    // Limpiar los tokens que ya no existen (app desinstalada, etc.)
    await Promise.all(
      res.responses.map((r, i) =>
        r.error?.code === "messaging/registration-token-not-registered"
          ? tokensRef.doc(tokens[i]).delete()
          : null,
      ),
    );
  },
);
