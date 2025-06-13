class PostReport {
  final int id;
  final int postId;
  final int userId;
  final String category;
  final String reason;
  final String status;
  final String createdAt;
  final String reporterNickname;
  final String postTitle;

  PostReport({
    required this.id,
    required this.postId,
    required this.userId,
    required this.category,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.reporterNickname,
    required this.postTitle,
  });

  factory PostReport.fromJson(Map<String, dynamic> json) {
    return PostReport(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      userId: json['user_id'] as int,
      category: json['category'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      reporterNickname: json['reporter_nickname'] ?? '',
      postTitle: json['post_title'] ?? '',
    );
  }
}
