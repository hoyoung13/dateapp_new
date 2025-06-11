import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Inquiry {
  final int id;
  final int userId;
  final String title;
  final String content;
  final String createdAt;
  final String? answer;
  final String status;

  Inquiry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.answer,
    required this.status,
  });

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      answer: json['answer'],
      status: json['status'] ?? 'pending',
    );
  }
}

class InquiryService {
  static Future<void> createInquiry(
      int userId, String title, String content) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/inquiries'),
      headers: {
        'Content-Type': 'application/json',
        'user_id': '$userId',
      },
      body: jsonEncode({'user_id': userId, 'title': title, 'content': content}),
    );

    if (response.statusCode != 200) {
      print('❌ 문의 등록 실패');
      print('응답 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');
      throw Exception('Failed to create inquiry');
    }
  }

  static Future<List<Inquiry>> fetchInquiries(int adminId) async {
    final resp = await http.get(
      Uri.parse('$BASE_URL/admin/inquiries'),
      headers: {'Content-Type': 'application/json', 'user_id': '$adminId'},
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = data['inquiries'] as List<dynamic>;
      return list
          .map((e) => Inquiry.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      print('❌ 문의 목록 조회 실패');
      print('응답 코드: ${resp.statusCode}');
      print('응답 본문: ${resp.body}');
      throw Exception('Failed to fetch inquiries');
    }
  }

  static Future<Inquiry> fetchInquiry(int id, int adminId) async {
    final resp = await http.get(
      Uri.parse('$BASE_URL/admin/inquiries/$id'),
      headers: {'Content-Type': 'application/json', 'user_id': '$adminId'},
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return Inquiry.fromJson(data['inquiry']);
    } else {
      print('❌ 문의 상세 조회 실패');
      print('응답 코드: ${resp.statusCode}');
      print('응답 본문: ${resp.body}');
      throw Exception('Failed to fetch inquiry');
    }
  }

  static Future<void> answerInquiry(int id, int adminId, String answer) async {
    final resp = await http.post(
      Uri.parse('$BASE_URL/admin/inquiries/$id/answer'),
      headers: {'Content-Type': 'application/json', 'user_id': '$adminId'},
      body: jsonEncode({'answer': answer, 'answerer_id': adminId}),
    );

    if (resp.statusCode != 200) {
      print('❌ 문의 답변 등록 실패');
      print('응답 코드: ${resp.statusCode}');
      print('응답 본문: ${resp.body}');
      throw Exception('Failed to submit answer');
    }
  }
}
