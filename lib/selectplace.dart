import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class SelectplacePage extends StatefulWidget {
  final Map<String, dynamic> collection;

  const SelectplacePage({Key? key, required this.collection}) : super(key: key);

  @override
  _SelectplacePageState createState() => _SelectplacePageState();
}

class _SelectplacePageState extends State<SelectplacePage> {
  Future<List<dynamic>>? _placesFuture;

  @override
  void initState() {
    super.initState();
    final int? collectionId = widget.collection['id'];
    if (collectionId != null) {
      _placesFuture = fetchPlacesInCollection(collectionId);
    }
  }

  Future<List<dynamic>> fetchPlacesInCollection(int collectionId) async {
    final url = Uri.parse('$BASE_URL/zzim/collection_places/$collectionId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['places'] as List<dynamic>;
      } else {
        print(
            "Failed to fetch places: ${response.statusCode} ${response.body}");
        return [];
      }
    } catch (error) {
      print("Error fetching places: $error");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("장소 선택"),
        backgroundColor: Colors.cyan[100],
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<dynamic>>(
          future: _placesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("오류 발생: ${snapshot.error}"));
            } else {
              final places = snapshot.data ?? [];
              if (places.isEmpty) {
                return const Center(child: Text("선택할 장소가 없습니다."));
              }
              return ListView.builder(
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];
                  return _buildPlaceCard(place);
                },
              );
            }
          },
        ),
      ),
    );
  }

  /// 카드 형태로 장소 표시
  Widget _buildPlaceCard(dynamic place) {
    // 이미지: images 배열의 첫번째 값 사용 (없으면 null)
    final String? imageUrl = (place['images'] != null &&
            place['images'] is List &&
            place['images'].isNotEmpty)
        ? place['images'][0].toString()
        : null;
    // 카테고리, 장소 이름, 별점, 해시태그
    final String category = place['main_category'] ?? '';
    final String placeName = place['place_name'] ?? '장소 이름 없음';
    final double rating = (place['rating'] != null)
        ? double.tryParse(place['rating'].toString()) ?? 0.0
        : 0.0;
    final List<String> hashtags =
        (place['hashtags'] != null && place['hashtags'] is List)
            ? List<String>.from(place['hashtags'])
            : [];

    return GestureDetector(
      // _buildPlaceCard 내 onTap 콜백 예시
      onTap: () {
        final selectedPlace = {
          'place_name': place['place_name'],
          'address': place['address'],
          'image': (place['images'] != null && place['images'].isNotEmpty)
              ? place['images'][0]
              : null,
          'id': place['id'], // 옵션: place id도 함께 반환
        };
        print("선택된 장소 데이터 (SelectplacePage): $selectedPlace");
        Navigator.pop(context, selectedPlace); // 선택한 장소 데이터 반환
      },

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: (imageUrl != null && imageUrl.startsWith("http"))
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      height: 180,
                      width: double.infinity,
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      height: 180,
                      width: double.infinity,
                      child: const Center(child: Text("이미지 없음")),
                    ),
            ),
            const SizedBox(height: 8),
            // 카테고리 (연한 회색)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                category,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 4),
            // 장소 이름과 우측 하트 아이콘
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      placeName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.favorite_border, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 별점
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 해시태그
            if (hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hashtags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("#$tag",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
