

import 'package:delivery_app/models/product_model.dart';

class PlateModel {
  final String id;
  final String name;
  final double price;
  final List<PlateItem> products;
   
   PlateModel({
    required this.id,
    required this.name,
    required this.price,
    required this.products,
   });
}

class PlateItem{
  final ProductModel product;
  int quantity;

  PlateItem({required this.product, required this.quantity});
}