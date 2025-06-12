class PlaceReport {
  final int id;
  final int placeId;
  final int userId;
  final String category;
  final String reason;
  final String status;
  final String createdAt;
  final String reporterNickname;
  final String placeName;

  PlaceReport({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.category,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.reporterNickname,
    required this.placeName,
  });

  factory PlaceReport.fromJson(Map<String, dynamic> json) {
    return PlaceReport(
      id: json['id'] as int,
      placeId: json['place_id'] as int,
      userId: json['user_id'] as int,
      category: json['category'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      reporterNickname: json['reporter_nickname'] ?? '',
      placeName: json['place_name'] ?? '',
    );
  }
}
