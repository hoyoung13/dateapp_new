import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'constants.dart';
import 'package:intl/intl.dart';
import 'theme_colors.dart';

class CouplePage extends StatefulWidget {
  const CouplePage({super.key});

  @override
  _CouplePageState createState() => _CouplePageState();
}

class _CouplePageState extends State<CouplePage> {
  Map<String, dynamic>? _coupleInfo;
  bool _isLoading = true;
  TextEditingController _nicknameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _startDateController = TextEditingController();

  int? _partnerId;
  String? _partnerNickname;

  @override
  void initState() {
    super.initState();
    _fetchCoupleInfo();
  }

  // ✅ 커플 정보 가져오기
  Future<void> _fetchCoupleInfo() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    if (userId == null) return;

    try {
      final response = await http.get(Uri.parse("$BASE_URL/couple/$userId"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _coupleInfo = data["couple"];
          _startDateController.text = _formatDate(data["couple"]["start_date"]);
          _isLoading = false;
        });
      } else {
        setState(() {
          _coupleInfo = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ 커플 정보 불러오기 실패: $e");
      setState(() {
        _coupleInfo = null;
        _isLoading = false;
      });
    }
  }

  // ✅ 닉네임 & 이메일로 사용자 검색 후 자동 커플 등록
  Future<void> _searchAndRegisterUser() async {
    try {
      final response = await http.get(Uri.parse(
          "$BASE_URL/couple/search-user?nickname=${_nicknameController.text}&email=${_emailController.text}"));
      print("✅ 서버 응답 상태 코드: ${response.statusCode}");
      print("✅ 서버 응답 본문: ${response.body}");
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData["user"] != null) {
        setState(() {
          _partnerId = responseData["user"]["id"];
          _partnerNickname = responseData["user"]["nickname"];
        });
        print("✅ 사용자 검색 성공: ID = $_partnerId");
        _registerCouple(); // 자동으로 커플 등록 실행
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("사용자를 찾을 수 없습니다.")),
        );
      }
    } catch (e) {
      print("❌ 사용자 검색 실패: $e");
    }
  }

  // ✅ 커플 등록
  Future<void> _registerCouple() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    if (userId == null || _partnerId == null) return;

    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/couple/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "partner_id": _partnerId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        print("✅ 커플 등록 성공: ${responseData['message']}");
        _fetchCoupleInfo();
      } else {
        print("❌ 커플 등록 실패: ${responseData['error']}");
      }
    } catch (e) {
      print("❌ 서버 오류 발생: $e");
    }
  }

  // ✅ 커플 해제
  Future<void> _deleteCouple() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    if (userId == null) return;

    try {
      final response =
          await http.delete(Uri.parse("$BASE_URL/couple/delete/$userId"));

      if (response.statusCode == 200) {
        print("✅ 커플 해제 성공");
        setState(() {
          _coupleInfo = null;
        });
      } else {
        print("❌ 커플 해제 실패");
      }
    } catch (e) {
      print("❌ 서버 오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("커플 관리"),
        backgroundColor: AppColors.appBar,
        actions: [
          TextButton(
            onPressed:
                _coupleInfo == null ? _showRegisterDialog : _deleteCouple,
            child: Text(
              _coupleInfo == null ? "커플 등록" : "커플 해제",
              style: TextStyle(
                  color: _coupleInfo == null ? Colors.blue : Colors.red),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupleInfo == null
              ? const Center(
                  child: Text("등록된 커플이 없습니다.", style: TextStyle(fontSize: 18)))
              : _buildCoupleInfoUI(),
    );
  }

// ✅ 사귄 일수 계산
  int _calculateDaysTogether(String startDate) {
    DateTime start = DateTime.parse(startDate);
    DateTime now = DateTime.now();
    return now.difference(start).inDays;
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("커플 등록"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(labelText: "상대방 닉네임")),
              TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "상대방 이메일")),
            ],
          ),
          actions: [
            TextButton(
                onPressed: _searchAndRegisterUser, child: const Text("커플 등록")),
          ],
        );
      },
    );
  }

  String _formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  }

  // ✅ 사귄 날짜 수정
  Future<void> _updateStartDate() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    if (userId == null) return;

    try {
      final response = await http.put(
        Uri.parse("$BASE_URL/couple/update-date"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "start_date": _startDateController.text,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ 사귄 날짜 수정 성공");
        _fetchCoupleInfo();
      } else {
        print("❌ 사귄 날짜 수정 실패");
      }
    } catch (e) {
      print("❌ 서버 오류 발생: $e");
    }
  }

  Widget _buildCoupleInfoUI() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoField("상대방 이름", _coupleInfo?["partner_name"] ?? ""),
          _buildInfoField("상대방 닉네임", _coupleInfo?["partner_nickname"] ?? ""),
          _buildInfoField("상대방 생년월일",
              _formatDate(_coupleInfo?["partner_birth_date"] ?? "")),
          _buildInfoField("사귄 일수",
              "${_calculateDaysTogether(_coupleInfo?["start_date"] ?? "")}일"),
          _buildInfoField(
              "사귄 날짜", _formatDate(_coupleInfo?["start_date"] ?? "")),
          const SizedBox(height: 10),
          ListTile(
            title: const Text("사귄 날짜 수정",
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showStartDateEditDialog,
          ),
          ListTile(
            title: const Text("커플 탈력"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text("커플 앨범"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text("커플 코스"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value, {bool enabled = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: value),
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

  void _showStartDateEditDialog() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.appBar, // 선택 색상 변경
            hintColor: AppColors.appBar,
            colorScheme: ColorScheme.light(primary: AppColors.appBar),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

      setState(() {
        _startDateController.text = formattedDate; // 선택한 날짜 UI 반영
      });

      _updateStartDate(); // 자동으로 API 호출
    }
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// ✅ 정보 표시 UI 개선
Widget _buildInfoRow(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}
