import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'constants.dart';

class UserProvider with ChangeNotifier {
  int? _userId;
  String? _nickname;
  String? _email;
  String? _name;
  String? _birthDate;
  String? _gender;
  String? _profileImagePath;
  bool _isAdmin = false;

  int? get userId => _userId;
  String? get nickname => _nickname;
  String? get email => _email;
  String? get name => _name;
  String? get birthDate => _birthDate;
  String? get gender => _gender;
  String? get profileImagePath => _profileImagePath;
  bool get isAdmin => _isAdmin;

  // ✅ 서버에서 사용자 데이터 가져오기 (로그인 후 프로필 불러오기)
  Future<void> fetchUserProfile(int userId) async {
    try {
      final response = await http.get(Uri.parse("$BASE_URL/profile/$userId"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)["user"];
        _userId = data["id"];
        _nickname = data["nickname"];
        _email = data["email"];
        _name = data["name"] ?? "";
        _birthDate = data["birth_date"] ?? "";
        _gender = data["gender"];

        // ✅ 프로필 이미지가 NULL이 아닐 경우만 업데이트
        if (data["profile_image"] != null && data["profile_image"].isNotEmpty) {
          _profileImagePath = "$BASE_URL${data["profile_image"]}";
        }
        print("📸 프로필 이미지 경로: $_profileImagePath"); // 디버깅 로그 추가

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("profile_image", _profileImagePath ?? "");

        notifyListeners();
      } else {
        print("❌ 프로필 불러오기 실패");
      }
    } catch (e) {
      print("❌ 서버 오류 발생: $e");
    }
  }

  Future<void> setUserData(Map<String, dynamic> userData) async {
    _userId = userData['id'];
    _nickname = userData['nickname'];
    _email = userData['email'];
    _name = userData['name'] ?? "";
    _birthDate = userData['birth_date'] ?? "";
    _gender = userData['gender'] ?? "";
    // ✅ profile_image가 null이면 빈 문자열을 할당
    _profileImagePath = userData['profile_image'] != null &&
            userData['profile_image'].isNotEmpty
        ? "$BASE_URL${userData['profile_image']}"
        : "";
    _isAdmin = userData['isAdmin'] == true;

    print("🔍 저장된 유저 정보:");
    print("이름: $_name");
    print("생년월일: $_birthDate");
    print("성별: $_gender");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("user_id", _userId!);
    await prefs.setString("nickname", _nickname!);
    await prefs.setString("email", _email!);
    await prefs.setString("name", _name!);
    await prefs.setString("birth_date", _birthDate!);
    await prefs.setString("gender", _gender!);
    await prefs.setString("profile_image", _profileImagePath!);
    await prefs.setBool("is_admin", _isAdmin);

    notifyListeners();
    await fetchUserProfile(_userId!);
  }

// ✅ 저장된 유저 정보 불러오기 (앱 실행 시 자동 로그인)
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt("user_id");
    _nickname = prefs.getString("nickname");
    _email = prefs.getString("email");
    _name = prefs.getString("name") ?? "";
    _birthDate = prefs.getString("birth_date") ?? "";
    _gender = prefs.getString("gender");
    _profileImagePath = prefs.getString("profile_image");
    _isAdmin = prefs.getBool("is_admin") ?? false;

    notifyListeners();
  }

  void updateUserInfo({
    int? userId,
    String? email,
    String? name,
    String? nickname,
    String? birthDate,
    String? gender,
    String? profileImagePath,
  }) async {
    if (userId != null) _userId = userId;
    if (email != null) _email = email;
    if (name != null) _name = name;
    if (nickname != null) _nickname = nickname;
    if (birthDate != null) _birthDate = birthDate;
    if (gender != null) _gender = gender;
    if (profileImagePath != null) _profileImagePath = profileImagePath;

    final prefs = await SharedPreferences.getInstance();
    if (_userId != null) await prefs.setInt("user_id", _userId!);
    if (_nickname != null) await prefs.setString("nickname", _nickname!);
    if (_email != null) await prefs.setString("email", _email!);
    if (_name != null) await prefs.setString("name", _name!);
    if (_birthDate != null) await prefs.setString("birth_date", _birthDate!);
    if (_gender != null) await prefs.setString("gender", _gender!);
    if (_profileImagePath != null)
      await prefs.setString("profile_image", _profileImagePath!);

    notifyListeners();
  }

  void clearUserData() async {
    _userId = null;
    _nickname = null;
    _email = null;
    _name = null;
    _birthDate = null;
    _gender = null;
    _isAdmin = false; // 메모리 상에서도 false 처리

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user_id"); // ✅ user_id만 삭제
    await prefs.remove("nickname");
    await prefs.remove("email");
    await prefs.remove("name");
    await prefs.remove("birth_date");
    await prefs.remove("gender");
    await prefs.remove("profile_image");
    // ─── 여기부터 추가 ───
    await prefs.remove("is_admin");
    notifyListeners();
  }
}
