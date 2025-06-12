import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';

class AdminEditPlacePage extends StatefulWidget {
  final int placeId;
  final int reportId;
  const AdminEditPlacePage({Key? key, required this.placeId, required this.reportId}) : super(key: key);

  @override
  State<AdminEditPlacePage> createState() => _AdminEditPlacePageState();
}

class _AdminEditPlacePageState extends State<AdminEditPlacePage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController mainCatCtrl = TextEditingController();
  final TextEditingController subCatCtrl = TextEditingController();
  final TextEditingController imagesCtrl = TextEditingController();
  final TextEditingController hashtagsCtrl = TextEditingController();

  int? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;
    _load();
  }

  Future<void> _load() async {
    final uri = Uri.parse('$BASE_URL/admin/places/${widget.placeId}');
    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'user_id': '${_adminId}'
    });
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() {
        nameCtrl.text = data['place_name'] ?? '';
        addressCtrl.text = data['address'] ?? '';
        phoneCtrl.text = data['phone'] ?? '';
        descCtrl.text = data['description'] ?? '';
        priceCtrl.text = jsonEncode(data['price_info'] ?? []);
        mainCatCtrl.text = data['main_category'] ?? '';
        subCatCtrl.text = data['sub_category'] ?? '';
        imagesCtrl.text = (data['images'] as List<dynamic>? ?? []).join(',');
        hashtagsCtrl.text = (data['hashtags'] as List<dynamic>? ?? []).join(',');
      });
    }
  }

  Future<void> _save() async {
    final uri = Uri.parse('$BASE_URL/admin/places/${widget.placeId}');
    await http.patch(uri,
        headers: {'Content-Type': 'application/json', 'user_id': '${_adminId}'},
        body: jsonEncode({
          'place_name': nameCtrl.text,
          'address': addressCtrl.text,
          'phone': phoneCtrl.text,
          'description': descCtrl.text,
          'price_info': priceCtrl.text.isNotEmpty ? jsonDecode(priceCtrl.text) : null,
          'main_category': mainCatCtrl.text,
          'sub_category': subCatCtrl.text,
          'images': imagesCtrl.text.isNotEmpty ? imagesCtrl.text.split(',') : null,
          'hashtags': hashtagsCtrl.text.isNotEmpty ? hashtagsCtrl.text.split(',') : null,
        }));

    final uri2 = Uri.parse('$BASE_URL/admin/place-reports/${widget.reportId}');
    await http.patch(uri2,
        headers: {'Content-Type': 'application/json', 'user_id': '${_adminId}'},
        body: jsonEncode({'message': '문의 내용이 수정되었습니다.'}));
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
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름')),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '주소')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '전화')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '설명')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: '가격정보(JSON)')),
            TextField(controller: mainCatCtrl, decoration: const InputDecoration(labelText: '메인 카테고리')),
            TextField(controller: subCatCtrl, decoration: const InputDecoration(labelText: '서브 카테고리')),
            TextField(controller: imagesCtrl, decoration: const InputDecoration(labelText: '이미지들(,로 구분)')),
            TextField(controller: hashtagsCtrl, decoration: const InputDecoration(labelText: '해시태그(,로 구분)')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
