import 'package:shared_preferences/shared_preferences.dart';

class AuthHelper {
  static Future<Map<String, String>> authHeaders(
      {bool json = true, int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (userId != null) headers['user_id'] = '$userId';
    return headers;
  }
}
