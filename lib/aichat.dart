// lib/aichat.dart
class ChatMessage {
  final String? text;
  final bool fromAI;
  final int? courseId;

  ChatMessage({this.text, required this.fromAI, this.courseId});
}
