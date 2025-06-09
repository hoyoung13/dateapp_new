// review_write_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'review_provider.dart';
import 'user_provider.dart';
import 'constants.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

class ReviewWritePage extends StatefulWidget {
  final int placeId;
  const ReviewWritePage({Key? key, required this.placeId}) : super(key: key);

  @override
  State<ReviewWritePage> createState() => _ReviewWritePageState();
}

class _ReviewWritePageState extends State<ReviewWritePage> {
  int _rating = 0;
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _hashtagCtrl = TextEditingController();
  List<String> _hashtags = [];
  List<XFile> _images = [];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked != null && picked.length + _images.length <= 5) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0 || _commentCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점과 코멘트는 필수입니다.')),
      );
      return;
    }

    final userProv = context.read<UserProvider>();
    final reviewProv = context.read<ReviewProvider>();
    final userId = userProv.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    // 1) 이미지는 미리 서버에 업로드해서 URL 받았다면 아래처럼 URL 리스트로 변환
    //    (아직 업로드 기능이 없다면 빈 리스트로 보내셔도 무방)
    final imageUrls = _images.map((f) {
      // e.g. https://cdn.yourserver.com/uploads/파일명.jpg
      final filename = path.basename(f.path);
      return '$BASE_URL/uploads/$filename';
    }).toList();

    // 2) POST /reviews 호출
    final uri = Uri.parse('$BASE_URL/api/reviews');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'place_id': widget.placeId,
        'user_id': userId,
        'rating': _rating,
        'comment': _commentCtrl.text,
        'hashtags': _hashtags, // List<String>
        'images': imageUrls, // List<String>
      }),
    );

    if (resp.statusCode == 201) {
      // 서버에 저장한 뒤, 최신 리뷰 목록을 다시 불러옵니다.
      await reviewProv.fetchReviews(widget.placeId);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리뷰 저장에 실패했습니다. (${resp.statusCode})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('리뷰 작성'),
        backgroundColor: Colors.pink,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('별점을 선택해주세요.', style: TextStyle(fontSize: 16)),
            Row(
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.pink,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = i + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('리뷰를 작성해주세요.', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _commentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '매장이나 구매한 상품에 대한 리뷰를 작성해주세요.',
              ),
            ),
            const SizedBox(height: 16),
            const Text('해시태그를 작성해주세요.', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagCtrl,
                    decoration: const InputDecoration(hintText: '해시태그 추가'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final tag = _hashtagCtrl.text.trim();
                    if (tag.isNotEmpty && !_hashtags.contains(tag)) {
                      setState(() {
                        _hashtags.add(tag);
                      });
                      _hashtagCtrl.clear();
                    }
                  },
                )
              ],
            ),
            Wrap(
              spacing: 8,
              children: _hashtags
                  .map((t) => Chip(
                        label: Text('#$t'),
                        onDeleted: () => setState(() {
                          _hashtags.remove(t);
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('사진을 올려주세요. (최대 5장)', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var img in _images)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.file(File(img.path),
                          width: 80, height: 80, fit: BoxFit.cover),
                      GestureDetector(
                        onTap: () => setState(() {
                          _images.remove(img);
                        }),
                        child: const Icon(Icons.close, color: Colors.white),
                      )
                    ],
                  ),
                if (_images.length < 5)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                child: const Text('리뷰 업로드'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
