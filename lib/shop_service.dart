import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

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
  static Future<Map<String, String>> _authHeaders(
      {bool json = true, int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (userId != null) headers['user_id'] = '$userId';
    return headers;
  }

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

  static Future<Purchase> purchaseItem(int itemId) async {
    final headers = await _authHeaders();

    final resp = await http.post(
      Uri.parse('$BASE_URL/shop/purchase'),
      headers: headers,
      body: jsonEncode({'item_id': itemId}),
    );
    if (resp.statusCode == 201) {
      return Purchase.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to purchase item');
    }
  }

  static Future<List<Purchase>> fetchPurchaseHistory(int userId) async {
    final headers = await _authHeaders(json: false);
    final resp = await http.get(Uri.parse('$BASE_URL/shop/purchases/$userId'),
        headers: headers);
    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      return data
          .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load purchase history');
    }
  }

  static Future<String> uploadItemImage(File image) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$BASE_URL/shop/admin/upload-item-image'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(respStr) as Map<String, dynamic>;
      return data['image_url'] as String;
    } else {
      throw Exception('Failed to upload image');
    }
  }

  // Admin APIs
  static Future<List<ShopItem>> fetchAdminItems(int adminId) async {
    final headers = await _authHeaders(userId: adminId);

    final resp = await http.get(
      Uri.parse('$BASE_URL/shop/admin/items'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      return data
          .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load items');
    }
  }

  static Future<void> createItem(int adminId, String category, String name,
      String imageUrl, int pricePoints) async {
    final headers = await _authHeaders(userId: adminId);

    final resp = await http.post(
      Uri.parse('$BASE_URL/shop/admin/items'),
      headers: headers,
      body: jsonEncode({
        'category': category,
        'name': name,
        'image_url': imageUrl,
        'price_points': pricePoints,
      }),
    );
    if (resp.statusCode != 201) {
      throw Exception('Failed to create item');
    }
  }

  static Future<void> updateItem(int adminId, int id, String category,
      String name, String imageUrl, int pricePoints) async {
    final headers = await _authHeaders(userId: adminId);

    final resp = await http.patch(
      Uri.parse('$BASE_URL/shop/admin/items/$id'),
      headers: headers,
      body: jsonEncode({
        'category': category,
        'name': name,
        'image_url': imageUrl,
        'price_points': pricePoints,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to update item');
    }
  }

  static Future<void> deleteItem(int adminId, int id) async {
    final headers = await _authHeaders(userId: adminId);

    final resp = await http.delete(
      Uri.parse('$BASE_URL/shop/admin/items/$id'),
      headers: headers,
    );
    if (resp.statusCode != 204) {
      throw Exception('Failed to delete item');
    }
  }
}
