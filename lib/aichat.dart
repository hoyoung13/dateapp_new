// lib/aichat.dart
class ChatMessage {
  final String? text;
  final bool fromAI;
  final int? courseId;
  final List<dynamic>? coursePreview;
  final String? courseName;
  ChatMessage({
    this.text,
    required this.fromAI,
    this.courseId,
    this.coursePreview,
    this.courseName,
  });
}
