import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlacePage extends StatefulWidget {
  const PlacePage({super.key});

  @override
  _PlacePageState createState() => _PlacePageState();
}

class _PlacePageState extends State<PlacePage> {
  TextEditingController searchController = TextEditingController();
  List places = [];

  Future<void> fetchPlaces(String query) async {
    final String? clientId = dotenv.env['NAVER_CLIENT_ID'];
    final String? clientSecret = dotenv.env['NAVER_CLIENT_SECRET'];

    if (clientId == null || clientSecret == null) {
      print("❌ 네이버 API 키가 존재하지 않습니다. .env 파일을 확인하세요.");
      return;
    }

    final String url =
        "https://openapi.naver.com/v1/search/local.json?query=${Uri.encodeComponent(query)}&display=5";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "X-Naver-Client-Id": clientId,
        "X-Naver-Client-Secret": clientSecret,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        places = data['items'];
      });
      print("✅ 네이버 장소 검색 결과: ${data['items']}");
    } else {
      print("❌ 네이버 API 요청 실패: ${response.statusCode} / ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB9FDF9),
        title: const Text(
          '장소 검색',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '등록하고자 하는 장소의 이름을 입력하세요',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "장소 이름 입력",
                filled: true,
                fillColor: const Color(0xFFD9D9D9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.black),
                  onPressed: () {
                    fetchPlaces(searchController.text);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];
                  return ListTile(
                    title:
                        Text(place['title'].replaceAll(RegExp(r'<[^>]*>'), '')),
                    subtitle: Text(place['address']),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/CategorySelectionPage',
                        arguments: {
                          'place_name':
                              place['title'].replaceAll(RegExp(r'<[^>]*>'), ''),
                          'address': place['address']
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
