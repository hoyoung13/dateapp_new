import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class PointHistory {
  final int id;
  final int userId;
  final String action;
  final int points;
  final String createdAt;

  PointHistory({
    required this.id,
    required this.userId,
    required this.action,
    required this.points,
    required this.createdAt,
  });

  factory PointHistory.fromJson(Map<String, dynamic> json) {
    return PointHistory(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      action: json['action'] ?? '',
      points: json['points'] as int,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PointHistoryService {
  static Future<List<PointHistory>> fetchPointHistory(int userId) async {
    final resp = await http.get(Uri.parse('$BASE_URL/points/history/$userId'));
    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      return data
          .map((e) => PointHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load point history');
    }
  }
}
