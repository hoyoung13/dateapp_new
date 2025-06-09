import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = "남성"; // 기본값 설정
  File? _profileImage; // ✅ 선택한 프로필 이미지

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      print("🔍 불러온 유저 정보:");
      print("이름: ${userProvider.name}");
      print("생년월일: ${userProvider.birthDate}");
      print("성별: ${userProvider.gender}");

      setState(() {
        _nicknameController.text = userProvider.nickname ?? "";
        _dobController.text = userProvider.birthDate ?? "";
        _emailController.text = userProvider.email ?? "";
        _nameController.text = userProvider.name ?? "";
        _selectedGender = userProvider.gender ?? "남성";
      });
    });
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    _nicknameController.text = userProvider.nickname ?? "";
    _dobController.text = userProvider.birthDate ?? "";
    _emailController.text = userProvider.email ?? "";
    _nameController.text = userProvider.name ?? "";
    _selectedGender = userProvider.gender ?? "남성"; // 기본값 설정

    if (userProvider.profileImagePath != null &&
        userProvider.profileImagePath!.isNotEmpty) {
      _profileImage = File(userProvider.profileImagePath!);
    }
  }

// ✅ 서버에 이미지 업로드
  Future<void> _uploadProfileImage(File image) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;
    if (userId == null) return;

    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$BASE_URL/profile/upload-profile-image/$userId"), // ✅ 올바른 URL
    );

    request.files.add(await http.MultipartFile.fromPath("image", image.path));

    try {
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print("📤 서버 응답 코드: ${response.statusCode}");
      print("📤 서버 응답 본문: $responseData");

      if (response.statusCode == 200) {
        var json = jsonDecode(responseData);
        setState(() {
          _profileImage = image;
        });

        userProvider.updateUserInfo(
            profileImagePath: "$BASE_URL${json["profile_image"]}");
      } else {
        print("❌ 프로필 이미지 업로드 실패 (서버 응답 코드: ${response.statusCode})");
      }
    } catch (e) {
      print("❌ 프로필 이미지 업로드 중 오류 발생: $e");
    }
  }

  // ✅ 이미지 선택 함수
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _uploadProfileImage(imageFile);
    }
  }

  // ✅ 정보 저장 함수
  void _saveProfile() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.updateUserInfo(
      nickname: _nicknameController.text,
      birthDate: _dobController.text,
      email: _emailController.text,
      name: _nameController.text,
      gender: _selectedGender, // 성별 저장
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("정보가 수정되었습니다.")),
    );

    Navigator.pop(context); // 마이페이지로 이동
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    String? profileImagePath = userProvider.profileImagePath;

    return Scaffold(
      appBar: AppBar(
        title: const Text("내 정보 수정"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ 프로필 이미지 섹션
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: userProvider.profileImagePath != null &&
                              userProvider.profileImagePath!.isNotEmpty
                          ? NetworkImage(userProvider.profileImagePath!)
                              as ImageProvider
                          : AssetImage('assets/profile.png'), // 기본 이미지
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const Icon(Icons.camera_alt, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ✅ 이메일
              _buildInfoField("이메일", _emailController, enabled: false),

              // ✅ 이름
              _buildInfoField("이름", _nameController, enabled: false),

              // ✅ 닉네임
              _buildInfoField("닉네임", _nicknameController),

              // ✅ 성별 선택
              _buildGenderSelector(),

              // ✅ 생년월일 입력
              _buildInfoField("생년월일", _dobController),

              const SizedBox(height: 20),

              // ✅ 정보 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("정보 저장", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 입력 필드 UI 공통 함수
  Widget _buildInfoField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            fillColor: enabled ? Colors.white : Colors.grey[200],
            filled: true,
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  // ✅ 성별 선택 UI
  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("성별", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: RadioListTile(
                title: const Text("남성"),
                value: "남성",
                groupValue: _selectedGender,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value.toString();
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile(
                title: const Text("여성"),
                value: "여성",
                groupValue: _selectedGender,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value.toString();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
