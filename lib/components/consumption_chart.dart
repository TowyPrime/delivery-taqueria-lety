import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

/// Cantidad de barras (productos más consumidos) que se dibujan.
const int _maxBars = 4;

/// Con 4 barras en un móvil caben ~10 caracteres bajo cada una.
const int _maxLabelChars = 10;

class ConsumptionChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> orders;

  const ConsumptionChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // Procesar los datos de Firestore para agrupar las cantidades por producto
    final Map<String, int> productQuantities = consumptionByProduct(
      orders.map((doc) => doc.data() as Map<String, dynamic>),
    );

    // Si no hay datos aún
    if (productQuantities.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos suficientes para graficar',
          style: TextStyle(color: AppColors.inkSoft),
        ),
      );
    }

    // Ordenamos los productos para tomar sólo los 4 más consumidos y no saturar la barra
    final sortedProducts = productQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topProducts = sortedProducts.take(_maxBars).toList();

    // Encontramos el valor máximo para ajustar la escala del eje Y
    final double maxQuantity = topProducts.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(top: 20.0, right: 16.0, left: 8.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxQuantity + 2, // Margen superior dinámico
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColors.primaryDark,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} u.',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < topProducts.length) {
                    // Cortamos el nombre si es muy largo
                    String name = topProducts[index].key;
                    if (name.length > _maxLabelChars) {
                      name = '${name.substring(0, _maxLabelChars - 1)}…';
                    }
                    
                    return SideTitleWidget(
                      meta:meta,
                      space: 8,
                      child: Text(
                        name,
                        style: TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 2 == 0) { // Solo pinta números pares en el eje Y para limpieza visual
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 10),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          barGroups: List.generate(topProducts.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: topProducts[index].value.toDouble(),
                  color: AppColors.primary,
                  width: 22,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxQuantity + 2,
                    color: AppColors.background, // Fondo claro de barra
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Suma cuántas unidades de cada producto aparecen en los pedidos.
///
/// Reconoce los dos formatos de plato que existen en Firestore:
/// * `type: 'plato'` con `products` (pedidos creados desde el carrito).
/// * `isPlate: true` con `details` (platos agregados a un pedido existente).
@visibleForTesting
Map<String, int> consumptionByProduct(
  Iterable<Map<String, dynamic>> orders,
) {
  final Map<String, int> productQuantities = {};

  int asInt(Object? v) => (v as num?)?.toInt() ?? 0;

  void add(String name, int qty) {
    productQuantities[name] = (productQuantities[name] ?? 0) + qty;
  }

  for (final data in orders) {
    // Obtenemos el array de "items" que contiene esta orden específica
    final List<dynamic> items = data['items'] ?? [];

    for (final item in items) {
      final String itemType = item['type'] ?? 'individual';
      final int itemQuantity = asInt(item['quantity']);
      final bool isPlate = itemType == 'plato' || item['isPlate'] == true;

      if (isPlate) {
        final List<dynamic> innerProducts =
            item['products'] ?? item['details'] ?? [];

        for (final prod in innerProducts) {
          add(
            prod['name'] ?? 'Desconocido',
            asInt(prod['quantity']) * itemQuantity,
          );
        }
      } else {
        add(item['name'] ?? 'Desconocido', itemQuantity);
      }
    }
  }

  return productQuantities;
}
