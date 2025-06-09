import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'constants.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  String _selectedGender = "male"; // 기본값 (남성)

  // ✅ 중복 확인 결과 저장
  bool _isNicknameAvailable = false;
  bool _isEmailAvailable = false;

  // ✅ 닉네임 중복 확인
  Future<void> _checkNickname() async {
    final response = await http.get(
      Uri.parse(
          "$BASE_URL/auth/check-nickname?nickname=${_nicknameController.text}"),
    );
    final responseData = jsonDecode(response.body);

    setState(() {
      _isNicknameAvailable = responseData["available"];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(responseData["message"])),
    );
  }

  // ✅ 이메일 중복 확인
  Future<void> _checkEmail() async {
    final response = await http.get(
      Uri.parse("$BASE_URL/auth/check-email?email=${_emailController.text}"),
    );
    final responseData = jsonDecode(response.body);

    setState(() {
      _isEmailAvailable = responseData["available"];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(responseData["message"])),
    );
  }

  // ✅ 회원가입 요청
  Future<void> _signup() async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/auth/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nickname": _nicknameController.text,
          "email": _emailController.text,
          "password": _passwordController.text,
          "name": _nameController.text,
          "birth_date": _birthDateController.text, // "YYYY-MM-DD" 형식
          "gender": _selectedGender, // ✅ 성별 추가
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        Provider.of<UserProvider>(context, listen: false)
            .setUserData(responseData["user"]);
        Navigator.pushReplacementNamed(context, "/login");
      } else {
        print("❌ 회원가입 실패: ${responseData["error"]}");
      }
    } catch (e) {
      print("❌ 회원가입 요청 중 오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  '회원가입',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ 닉네임 입력 + 중복 확인 버튼
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: "닉네임",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _checkNickname,
                    child: const Text("중복 확인"),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ✅ 이메일 입력 + 중복 확인 버튼
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "이메일",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _checkEmail,
                    child: const Text("중복 확인"),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ✅ 비밀번호 입력
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "비밀번호",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // ✅ 이름 입력
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "이름",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // ✅ 생년월일 입력
              TextField(
                controller: _birthDateController,
                decoration: InputDecoration(
                  labelText: "생년월일 (YYYY-MM-DD)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ 성별 선택 (라디오 버튼)
              const Text("성별"),
              Row(
                children: [
                  Radio(
                    value: "male",
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value.toString();
                      });
                    },
                  ),
                  const Text("남성"),
                  Radio(
                    value: "female",
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value.toString();
                      });
                    },
                  ),
                  const Text("여성"),
                ],
              ),

              // ✅ 회원가입 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _signup,
                  child: const Text(
                    "회원가입",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
