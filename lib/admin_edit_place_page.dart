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

class AdminEditPlacePage extends StatefulWidget {
  final int placeId;
  final int reportId;
  final String? reason;
  final String? category;

  const AdminEditPlacePage({
    Key? key,
    required this.placeId,
    required this.reportId,
    this.reason,
    this.category,
  }) : super(key: key);

  @override
  State<AdminEditPlacePage> createState() => _AdminEditPlacePageState();
}

class _AdminEditPlacePageState extends State<AdminEditPlacePage> {
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
      setState(() {
        nameCtrl.text = data['place_name'] ?? '';
        addressCtrl.text = data['address'] ?? '';
        phoneCtrl.text = data['phone'] ?? '';
        descCtrl.text = data['description'] ?? '';
        priceCtrl.text = jsonEncode(data['price_info'] ?? []);
        selectedMainCategory = data['main_category'];
        selectedSubCategory = data['sub_category'];
        images
          ..clear()
          ..addAll((data['images'] as List<dynamic>? ?? [])
              .map((e) => e.toString()));
        hashtags
          ..clear()
          ..addAll((data['hashtags'] as List<dynamic>? ?? [])
              .map((e) => e.toString()));
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
    await http.patch(uri,
        headers: headers,
        body: jsonEncode({
          'place_name': nameCtrl.text,
          'address': addressCtrl.text,
          'phone': phoneCtrl.text,
          'description': descCtrl.text,
          'price_info':
              priceCtrl.text.isNotEmpty ? jsonDecode(priceCtrl.text) : null,
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
            ElevatedButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
