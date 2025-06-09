import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adminpage.dart';
import 'user_provider.dart';
import 'constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ✅ 일반 로그인 (이메일 & 비밀번호)

  Future<void> _login() async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      print("📥 서버 응답 상태 코드: ${response.statusCode}");
      print("📥 서버 응답 본문: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("✅ 로그인 성공: ${responseData["user"]}");

        // 1) Provider에 사용자 데이터 저장 (기존대로)
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.setUserData(responseData["user"]);
        // ─────────────────────────────────────────────────────────────────
        // ★★★ 여기까지는 기존 코드와 동일합니다. ★★★
        // ─────────────────────────────────────────────────────────────────

        // 2) SharedPreferences에 “로그인 상태” 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.setInt("user_id", responseData["user"]["id"]);

        // ─────────────────────────────────────────────────────────────────
        // ─── 이 아래부터 “isAdmin 분기”를 추가해야 합니다. ───
        // ─────────────────────────────────────────────────────────────────

        // 3) 서버 응답에서 isAdmin을 꺼내서 저장
        final userJson = responseData["user"] as Map<String, dynamic>;
        final bool isAdmin = (userJson["isAdmin"] == true);
        await prefs.setBool("is_admin", isAdmin);

        // 4) isAdmin 여부에 따라 서로 다른 페이지로 이동
        if (isAdmin) {
          // ▷ 관리자라면 '/admin_dashboard' (예시 라우트)로 이동
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          // ▷ 일반 사용자라면 기존 홈('/home')으로 이동
          Navigator.pushReplacementNamed(context, '/home');
        }

        return; // 이 시점에서 함수 종료
        // ─────────────────────────────────────────────────────────────────
        // ─── “isAdmin 분기” 처리 끝 ────────────────────────────────────
        // ─────────────────────────────────────────────────────────────────
      } else {
        final responseData = jsonDecode(response.body);
        print("❌ 로그인 실패: ${responseData["error"]}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 실패: ${responseData["error"]}")),
        );
      }
    } catch (e) {
      print("❌ 로그인 요청 중 오류 발생: $e");
    }
  }

  /*Future<void> _login() async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      print("📥 서버 응답 상태 코드: ${response.statusCode}");
      print("📥 서버 응답 본문: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        Map<String, dynamic> userData = responseData["user"];
        userData["profile_image"] = userData["profile_image"] ?? "";

        print("✅ 로그인 성공: ${responseData["user"]}");
        await userProvider.setUserData(userData);
        if (userData["id"] != null) {
          await userProvider.fetchUserProfile(userData["id"]);
        } else {
          print("❌ userId가 null이므로 fetchUserProfile 호출을 건너뜁니다.");
        }
        // ✅ SharedPreferences에 로그인 정보 저장 (자동 로그인)
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool("isLoggedIn", true);
        await prefs.setInt("user_id", userData["id"]);
        await prefs.setString("nickname", userData["nickname"] ?? "");
        await prefs.setString("email", userData["email"] ?? "");
        await prefs.setString("profile_image", userData["profile_image"]);
        await prefs.setString(
            "birth_date", responseData["user"]["birth_date"] ?? "");

        // 홈 화면으로 이동
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final responseData = jsonDecode(response.body);
        print("❌ 로그인 실패: ${responseData["error"]}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 실패: ${responseData["error"]}")),
        );
      }
    } catch (e) {
      print("❌ 로그인 요청 중 오류 발생: $e");
    }
  }
*/
  //카카오 로그인 및 users테이블에 집어넣기
  Future<void> _kakaoLogin() async {
    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;

      if (isInstalled) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      print('✅ 카카오 로그인 성공: ${token.accessToken}');

      // 🔹 카카오 유저 정보 가져오기
      User user = await UserApi.instance.me();
      String userName = user.kakaoAccount?.profile?.nickname ?? "사용자";
      String userEmail = user.kakaoAccount?.email ?? "";
      int kakaoId = user.id; // ✅ 카카오에서 제공하는 고유 ID 가져오기

      print("✅ 카카오 사용자 이름: $userName");
      print("✅ 카카오 사용자 이메일: $userEmail");
      print("✅ 카카오 사용자 ID: $kakaoId");

      // ✅ 🔥 서버에 사용자 정보 저장 요청 (여기가 중요함!)
      final response = await http.post(
        Uri.parse("$BASE_URL/auth/kakao-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,
          "nickname": userName,
          "kakao_id": kakaoId, // ✅ 변경됨!
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ 서버에 카카오 사용자 저장 성공!");
        final responseData = jsonDecode(response.body);

        // ✅ UserProvider에 저장
        Provider.of<UserProvider>(context, listen: false)
            .setUserData(responseData["user"]);

        // ✅ SharedPreferences에 저장 (자동 로그인)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.setInt("user_id", responseData["user"]["id"]);
        await prefs.setString(
            "nickname", responseData["user"]["nickname"] ?? "");
        await prefs.setString("email", responseData["user"]["email"] ?? "");
        await prefs.setString("name", responseData["user"]["name"] ?? "");
        await prefs.setString(
            "birth_date", responseData["user"]["birth_date"] ?? "");

        // 홈 화면으로 이동
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        print("❌ 서버에 사용자 저장 실패: ${response.body}");
      }
    } catch (e) {
      print('❌ 카카오 로그인 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("카카오 로그인 실패: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 422,
          height: 840,
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 상단 앱 아이콘 자리
              const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    "DATE IT",
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, // 🔹 Bold 적용
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 이메일 입력 필드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39),
                child: SizedBox(
                  height: 54,
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: "이메일",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          width: 1,
                          color: Colors.black.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          width: 1,
                          color: Colors.blue,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 비밀번호 입력 필드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39),
                child: SizedBox(
                  height: 54,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "비밀번호",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          width: 1,
                          color: Colors.black.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          width: 1,
                          color: Colors.blue,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 일반 로그인 버튼 (이메일 & 비밀번호)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF80E9FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _login, // 🔹 로그인 요청 실행
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 ✅ 카카오 로그인 버튼 ✅
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _kakaoLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '카카오 로그인',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 회원가입 & 비밀번호 찾기 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 39),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                              fontSize: 24,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: TextButton(
                          onPressed: () {
                            // 비밀번호 찾기 기능 추가 예정
                          },
                          child: const Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              fontSize: 24,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
