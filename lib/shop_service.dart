import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ShopItem {
  final int id;
  final String category;
  final String name;
  final String imageUrl;
  final int pricePoints;

  ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.imageUrl,
    required this.pricePoints,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as int,
      category: json['category'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      pricePoints: json['price_points'] as int,
    );
  }
}

class Purchase {
  final int id;
  final int itemId;
  final String itemName;
  final String imageUrl;
  final String barcode;
  final String purchasedAt;

  Purchase({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.imageUrl,
    required this.barcode,
    required this.purchasedAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as int,
      itemId: json['item_id'] as int,
      itemName: json['item_name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      barcode: json['barcode'] ?? '',
      purchasedAt: json['purchased_at'] ?? '',
    );
  }
}

class ShopService {
  static Future<List<ShopItem>> fetchItems(String category) async {
    final resp =
        await http.get(Uri.parse('$BASE_URL/shop/items?category=$category'));
    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      return data
          .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load items');
    }
  }

  static Future<Purchase> purchaseItem(int userId, int itemId) async {
    final resp = await http.post(
      Uri.parse('$BASE_URL/shop/purchase'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'item_id': itemId}),
    );
    if (resp.statusCode == 201) {
      return Purchase.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to purchase item');
    }
  }

  static Future<List<Purchase>> fetchPurchaseHistory(int userId) async {
    final resp = await http.get(Uri.parse('$BASE_URL/shop/purchases/$userId'));
    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      return data
          .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load purchase history');
    }
  }
}
