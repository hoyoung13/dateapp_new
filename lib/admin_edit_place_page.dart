import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'image_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_picker_spinner/time_picker_spinner.dart';

class AdminEditPlaceFormPage extends StatefulWidget {
  final int placeId;
  final int reportId;
  final String? reason;
  final String? category;

  const AdminEditPlaceFormPage({
    Key? key,
    required this.placeId,
    required this.reportId,
    this.reason,
    this.category,
  }) : super(key: key);

  @override
  State<AdminEditPlaceFormPage> createState() => _AdminEditPlaceFormPageState();
}

class _AdminEditPlaceFormPageState extends State<AdminEditPlaceFormPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  String? selectedMainCategory;
  String? selectedSubCategory;

  final List<String> images = [];
  final List<String> hashtags = [];
  final TextEditingController _hashtagController = TextEditingController();
  Map<String, bool> selectedDays = {
    '월': false,
    '화': false,
    '수': false,
    '목': false,
    '금': false,
    '토': false,
    '일': false,
  };
  Map<String, int> startHour = {
    '월': 9,
    '화': 9,
    '수': 9,
    '목': 9,
    '금': 9,
    '토': 9,
    '일': 9,
  };
  Map<String, int> startMinute = {
    '월': 0,
    '화': 0,
    '수': 0,
    '목': 0,
    '금': 0,
    '토': 0,
    '일': 0,
  };
  Map<String, int> endHour = {
    '월': 18,
    '화': 18,
    '수': 18,
    '목': 18,
    '금': 18,
    '토': 18,
    '일': 18,
  };
  Map<String, int> endMinute = {
    '월': 0,
    '화': 0,
    '수': 0,
    '목': 0,
    '금': 0,
    '토': 0,
    '일': 0,
  };

  final ImagePicker _picker = ImagePicker();

  final Map<String, List<String>> subCategoryMap = const {
    '맛집': ['밥', '고기', '면', '해산물', '길거리', '샐러드', '피자/버거'],
    '카페/술집': ['커피', '차/음료', '디저트', '맥주', '소주', '막걸리', '칵테일/와인'],
    '놀기': ['실외활동', '실내활동', '게임/오락', '힐링', 'VR/방탈출', '만들기'],
    '보기': ['영화', '전시', '공연', '박물관', '스포츠', '쇼핑'],
    '걷기': ['시장', '공원', '테마거리', '야경/풍경', '문화제'],
  };

  int? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;
    _load();
  }

  Future<void> _load() async {
    final uri = Uri.parse('$BASE_URL/admin/places/${widget.placeId}');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      'Content-Type': 'application/json',
      'user_id': '${_adminId}'
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      String? main = data['main_category'];
      if (!subCategoryMap.containsKey(main)) {
        if (main == '먹기') {
          main = '맛집';
        } else if (main == '카페') {
          main = '카페/술집';
        } else if (main == '놀거리') {
          main = '놀기';
        } else {
          main = null;
        }
      }

      // Validate sub category if main category is valid
      String? sub = data['sub_category'];
      if (main == null || !(subCategoryMap[main]?.contains(sub) ?? false)) {
        sub = null;
      }
      setState(() {
        nameCtrl.text = data['place_name'] ?? '';
        addressCtrl.text = data['address'] ?? '';
        phoneCtrl.text = data['phone'] ?? '';
        descCtrl.text = data['description'] ?? '';
        priceCtrl.text = jsonEncode(data['price_info'] ?? []);
        selectedMainCategory = main;
        selectedSubCategory = sub;
        images
          ..clear()
          ..addAll((data['images'] as List<dynamic>? ?? [])
              .map((e) => e.toString()));
        hashtags
          ..clear()
          ..addAll((data['hashtags'] as List<dynamic>? ?? [])
              .map((e) => e.toString()));
        final op = data['operating_hours'] as Map<String, dynamic>? ?? {};
        selectedDays.forEach((day, _) {
          final val = op[day];
          if (val is Map) {
            selectedDays[day] = true;
            final s = (val['start'] ?? '09:00').split(':');
            final e = (val['end'] ?? '18:00').split(':');
            startHour[day] = int.tryParse(s[0]) ?? 9;
            startMinute[day] = int.tryParse(s[1]) ?? 0;
            endHour[day] = int.tryParse(e[0]) ?? 18;
            endMinute[day] = int.tryParse(e[1]) ?? 0;
          } else {
            selectedDays[day] = false;
          }
        });
      });
    }
  }

  void _addHashtag() {
    final text = _hashtagController.text.trim();
    if (text.isNotEmpty && !hashtags.contains(text)) {
      setState(() {
        hashtags.add(text);
      });
    }
    _hashtagController.clear();
  }

  void _removeHashtag(String tag) {
    setState(() {
      hashtags.remove(tag);
    });
  }

  void _toggleDaySelection(String day) {
    setState(() {
      selectedDays[day] = !(selectedDays[day] ?? false);
    });
  }

  void _showSpinnerTimePicker(BuildContext context, String day, bool isStart) {
    DateTime tempDate = DateTime(
      2023,
      1,
      1,
      isStart ? startHour[day]! : endHour[day]!,
      isStart ? startMinute[day]! : endMinute[day]!,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('시간 설정'),
          content: SizedBox(
            height: 200,
            child: TimePickerSpinner(
              is24HourMode: true,
              normalTextStyle:
                  const TextStyle(fontSize: 18, color: Colors.grey),
              highlightedTextStyle:
                  const TextStyle(fontSize: 24, color: Colors.black),
              spacing: 40,
              itemHeight: 40,
              isForce2Digits: true,
              time: tempDate,
              onTimeChange: (newTime) {
                tempDate = newTime;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (isStart) {
                    startHour[day] = tempDate.hour;
                    startMinute[day] = tempDate.minute;
                  } else {
                    endHour[day] = tempDate.hour;
                    endMinute[day] = tempDate.minute;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked != null) {
      setState(() {
        images.addAll(picked.map((e) => e.path));
      });
    }
  }

  Future<void> _save() async {
    final uri = Uri.parse('$BASE_URL/admin/places/${widget.placeId}');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      'Content-Type': 'application/json',
      'user_id': '${_adminId}'
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    Map<String, dynamic> operatingHours = {};
    selectedDays.forEach((day, isOpen) {
      if (isOpen) {
        final start =
            '${startHour[day]!.toString().padLeft(2, '0')}:${startMinute[day]!.toString().padLeft(2, '0')}';
        final end =
            '${endHour[day]!.toString().padLeft(2, '0')}:${endMinute[day]!.toString().padLeft(2, '0')}';
        operatingHours[day] = {'start': start, 'end': end};
      } else {
        operatingHours[day] = '휴무';
      }
    });
    await http.patch(uri,
        headers: headers,
        body: jsonEncode({
          'place_name': nameCtrl.text,
          'address': addressCtrl.text,
          'phone': phoneCtrl.text,
          'description': descCtrl.text,
          'price_info':
              priceCtrl.text.isNotEmpty ? jsonDecode(priceCtrl.text) : null,
          'operating_hours': operatingHours,
          'main_category': selectedMainCategory,
          'sub_category': selectedSubCategory,
          'images': images.isNotEmpty ? images : null,
          'hashtags': hashtags.isNotEmpty ? hashtags : null,
        }));

    final uri2 = Uri.parse('$BASE_URL/admin/place-reports/${widget.reportId}');
    await http.patch(uri2,
        headers: headers, body: jsonEncode({'message': '문의 내용이 수정되었습니다.'}));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _noIssue() async {
    final uri = Uri.parse('$BASE_URL/admin/place-reports/${widget.reportId}');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      'Content-Type': 'application/json',
      'user_id': '$_adminId'
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    await http.patch(uri,
        headers: headers, body: jsonEncode({'message': '장소 정보에 문제가 없습니다.'}));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 정보 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (widget.category != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('신고 카테고리: ${widget.category}'),
              ),
            if (widget.reason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('신고 사유: ${widget.reason}'),
              ),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '이름')),
            TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: '주소')),
            TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: '전화')),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '설명')),
            TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: '가격정보(JSON)')),
            DropdownButtonFormField<String>(
              value: selectedMainCategory,
              decoration: const InputDecoration(labelText: '메인 카테고리'),
              items: subCategoryMap.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() {
                selectedMainCategory = v;
                selectedSubCategory = null;
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedSubCategory,
              decoration: const InputDecoration(labelText: '서브 카테고리'),
              items: (selectedMainCategory != null
                      ? subCategoryMap[selectedMainCategory]!
                      : <String>[])
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => selectedSubCategory = v),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: images
                  .map((img) => Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image(
                            image: img.startsWith('http')
                                ? NetworkImage(resolveImageUrl(img))
                                : FileImage(File(img)) as ImageProvider,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                          GestureDetector(
                            onTap: () => setState(() => images.remove(img)),
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ))
                  .toList(),
            ),
            TextButton(onPressed: _pickImages, child: const Text('이미지 선택')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagController,
                    decoration: const InputDecoration(hintText: '해시태그 입력'),
                  ),
                ),
                IconButton(onPressed: _addHashtag, icon: const Icon(Icons.add)),
              ],
            ),
            if (hashtags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hashtags
                    .map((tag) => Chip(
                          label: Text('#$tag'),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () => _removeHashtag(tag),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 20),
            const Text('영업시간', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Column(
              children: selectedDays.entries.map((entry) {
                final day = entry.key;
                final isSelected = entry.value;
                return Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleDaySelection(day),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? Colors.grey[300] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.black),
                            ),
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected ? Colors.black : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: isSelected
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showSpinnerTimePicker(
                                            context, day, true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${startHour[day]!.toString().padLeft(2, '0')}:${startMinute[day]!.toString().padLeft(2, '0')}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text('~',
                                          style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 5),
                                      GestureDetector(
                                        onTap: () => _showSpinnerTimePicker(
                                            context, day, false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${endHour[day]!.toString().padLeft(2, '0')}:${endMinute[day]!.toString().padLeft(2, '0')}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text('휴무'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
