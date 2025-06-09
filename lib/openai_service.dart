import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String _apiKey;
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  OpenAIService(this._apiKey);

  Future<String> sendChat(List<Map<String, String>> messages) async {
    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: json.encode({
        'model': 'gpt-3.5-turbo',
        'messages': messages,
      }),
    );

    if (res.statusCode == 200) {
      // ★ 여기서 res.body 가 아니라 bodyBytes 를 utf8 로 디코딩 ★
      final utf8Body = utf8.decode(res.bodyBytes);
      final data = json.decode(utf8Body) as Map<String, dynamic>;
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('OpenAI API 오류(${res.statusCode}): ${res.body}');
    }
  }
}
