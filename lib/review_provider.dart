import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Review {
  final int id;
  final int userId;
  final String username;
  final int rating;
  final String comment;
  final List<String> hashtags;
  final List<String> images;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.username,
    required this.rating,
    required this.comment,
    this.hashtags = const [],
    this.images = const [],
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String,
      hashtags: List<String>.from(json['hashtags'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReviewProvider with ChangeNotifier {
  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _error;

  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// placeId에 대한 리뷰를 가져옵니다.
  Future<void> fetchReviews(int placeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await http.get(Uri.parse('$BASE_URL/api/reviews/$placeId'));

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body)['reviews'];
        _reviews = data.map((e) => Review.fromJson(e)).toList();
      } else {
        _error = '서버 오류 ${resp.statusCode}';
      }
    } catch (e) {
      _error = '네트워크 오류';
    }

    _isLoading = false;
    notifyListeners();
  }
}
