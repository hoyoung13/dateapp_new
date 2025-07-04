import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    Navigator.pushReplacementNamed(context, '/login');
  } on FirebaseAuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('회원가입 실패: \${e.message}')),
    );
  }
}

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          width: 1,
          color: Colors.black.withOpacity(0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          width: 1,
          color: Colors.blue,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 422,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
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
                        decoration: _inputDecoration('닉네임'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _checkNickname,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF80E9FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '중복 확인',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
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
                        decoration: _inputDecoration('이메일'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _checkEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF80E9FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '중복 확인',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // ✅ 비밀번호 입력
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('비밀번호'),
                ),
                const SizedBox(height: 15),

                // ✅ 이름 입력
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('이름'),
                ),
                const SizedBox(height: 15),

                // ✅ 생년월일 입력
                TextField(
                  controller: _birthDateController,
                  decoration: _inputDecoration('생년월일 (YYYY-MM-DD)'),
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
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF80E9FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
