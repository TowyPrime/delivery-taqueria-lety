# Reclamaciones (`claims`)

Guía del modelo de datos, índices y reglas de seguridad. Pensada también para
la futura app de administración de pedidos.

## Flujo

1. Cliente con sesión abre un pedido **entregado** → "Solicitar devolución".
2. Elige el tipo, explica qué pasó (mín. 10 caracteres) y adjunta **1 a 3 fotos**.
3. La app sube las fotos a Storage y, en **una transacción**, crea el documento
   en `claims` y marca el pedido (`hasClaim: true`, `claimId`).
4. El pedido **conserva su estado** (`entregado`). La reclamación lleva el suyo.
5. El negocio (app de administración) cambia `status` y llena `resolution`.
6. El cliente ve el avance en el detalle del pedido y con el asistente del chat.

## Colección `claims/{claimId}`

| Campo | Tipo | Requerido | Lo escribe | Notas |
|---|---|---|---|---|
| `orderId` | string | sí | app cliente | Pedido reclamado. |
| `userId` | string | sí | app cliente | Dueño. Debe ser el `uid` autenticado. |
| `userName` | string | no | app cliente | Copia del nombre para verlo sin más consultas. |
| `type` | string | sí | app cliente | `devolucion`, `cancelacion`, `queja`, `otro`. El cliente elige entre `devolucion`, `queja` y `otro`. |
| `reason` | string | sí | app cliente | 10–500 caracteres. |
| `status` | string | sí | cliente al crear (`abierta`); negocio después | `abierta` → `en_revision` → `resuelta` \| `rechazada`. |
| `evidenceUrls` | list\<string\> | sí | app cliente | 1–3 URLs de Storage. |
| `orderTotal` | number | no | app cliente | Monto del pedido al reclamar. |
| `orderStatusAtRequest` | string | no | app cliente | Estado del pedido al reclamar. |
| `contactPhone` | string | no | app cliente | Se omite si el perfil no tiene teléfono. |
| `createdAt` | timestamp | sí | servidor | `FieldValue.serverTimestamp()`. |
| `updatedAt` | timestamp | no | servidor | Última actualización. |
| `resolution` | string | no | **negocio** | Mensaje que verá el cliente. |
| `refundAmount` | number | no | **negocio** | Monto reembolsado, si aplica. |
| `resolvedAt` | timestamp | no | **negocio** | Cuándo se cerró. |

Folio que ve el cliente: los 6 primeros caracteres del id, en mayúsculas.

## Campos en `orders`

| Campo | Tipo | Notas |
|---|---|---|
| `paymentIntentId` | string \| null | Id del PaymentIntent de Stripe (para reembolsos). `null` mientras el cobro sea simulado. |
| `hasClaim` | bool | `true` cuando ya existe una reclamación. Evita duplicarla. |
| `claimId` | string \| null | Id de la reclamación. |

La app lee `paymentIntentId` (también acepta `PaymentIntentId`), `claimId` y
`hasClaim`. En pedidos anteriores sin estos campos, `hasClaim` se deduce de
`claimId` y por defecto es `false`.

## Índices compuestos

| Colección | Campos |
|---|---|
| `claims` | `userId` ascendente, `createdAt` descendente (lo usa el asistente) |
| `claims` (app de administración) | `status` ascendente, `createdAt` descendente |

Si falta alguno, Firestore imprime en la consola de depuración un enlace para
crearlo con un clic.

## Reglas de Firestore (sugeridas — revísalas y combínalas con las tuyas)

Firestore combina varias reglas `allow` con OR, así que esto se **agrega** a las
reglas que ya tienes para `orders`.

```
function signedIn() { return request.auth != null; }
function isAdmin()  { return signedIn() && request.auth.token.admin == true; }

match /claims/{claimId} {
  allow read: if isAdmin()
              || (signedIn() && resource.data.userId == request.auth.uid);

  allow create: if signedIn()
    && request.resource.data.userId == request.auth.uid
    && get(/databases/$(database)/documents/orders/$(request.resource.data.orderId))
         .data.userId == request.auth.uid
    && request.resource.data.status == 'abierta'
    && request.resource.data.type in ['devolucion', 'cancelacion', 'queja', 'otro']
    && request.resource.data.reason is string
    && request.resource.data.reason.size() >= 10
    && request.resource.data.reason.size() <= 500
    && request.resource.data.evidenceUrls is list
    && request.resource.data.evidenceUrls.size() >= 1
    && request.resource.data.evidenceUrls.size() <= 3
    && request.resource.data.createdAt == request.time
    && !('resolution' in request.resource.data)
    && !('refundAmount' in request.resource.data)
    && !('resolvedAt' in request.resource.data);

  // Solo el negocio cambia estado y resolución.
  allow update: if isAdmin();
  allow delete: if false;
}

match /orders/{orderId} {
  // El dueño puede marcar su pedido con la reclamación (una sola vez).
  allow update: if signedIn()
    && resource.data.userId == request.auth.uid
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['hasClaim', 'claimId', 'updatedAt'])
    && request.resource.data.hasClaim == true
    && resource.data.get('hasClaim', false) == false;
}
```

## Reglas de Storage (sugeridas)

```
match /claims/{userId}/{claimId}/{file} {
  allow read: if request.auth != null
              && (request.auth.uid == userId || request.auth.token.admin == true);
  allow write: if request.auth != null
               && request.auth.uid == userId
               && request.resource.size < 5 * 1024 * 1024
               && request.resource.contentType.matches('image/.*');
}
```

## App de administración

* Marca a los administradores con un *custom claim* `admin: true` (Firebase
  Admin SDK). Sin eso, las reglas anteriores no le dejarán leer ni actualizar
  reclamaciones de otros usuarios.
* Para resolver: cambiar `status`, llenar `resolution` (y `refundAmount` si hay
  reembolso), `resolvedAt` y `updatedAt`.
* Para reembolsar por Stripe hace falta `orders/{id}.paymentIntentId`.

## Dónde está en el código

| Pieza | Archivo |
|---|---|
| Modelo, estados y reglas del formulario | `lib/models/claim_model.dart` |
| Crear / consultar reclamaciones | `lib/services/claim_service.dart` |
| Formulario (foto + explicación) | `lib/screens/claim_form_screen.dart` |
| Detalle del pedido con estado de la reclamación | `lib/screens/order_detail_widget.dart` |
| Respuesta del asistente | `lib/services/chat_bot.dart`, textos en `lib/config/chat_bot_config.dart` |
