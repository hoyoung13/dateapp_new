import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'selectplace.dart';
import 'allplace.dart';
import 'theme_colors.dart';

class ZzimListDialog extends StatefulWidget {
  final int userId;

  const ZzimListDialog({Key? key, required this.userId}) : super(key: key);

  @override
  State<ZzimListDialog> createState() => _ZzimListDialogState();
}

class _ZzimListDialogState extends State<ZzimListDialog> {
  Future<List<dynamic>>? _collectionsFuture;

  @override
  void initState() {
    super.initState();
    _collectionsFuture = fetchCollections(widget.userId);
  }

  Future<List<dynamic>> fetchCollections(int userId) async {
    final url = Uri.parse('$BASE_URL/zzim/collections/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["collections"] as List<dynamic>;
      } else {
        print(
            "Failed to fetch collections: ${response.statusCode} ${response.body}");
        return [];
      }
    } catch (error) {
      print("Error fetching collections: $error");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("찜 목록",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 2) 여기에 '장소 보러가기' 버튼 추가
            // ZzimListDialog.dart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  // 바로 AllPlacePage 로 이동
                  final Map<String, dynamic>? selectedPlace =
                      await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(builder: (_) => AllplacePage()),
                  );
                  // CoursePlacePage 에서 pop(widget.payload) 한 payload 를 받으면
                  if (selectedPlace != null) {
                    // 이 Dialog 도 닫으면서 상위(course.dart)로 전달
                    Navigator.of(context).pop(selectedPlace);
                  }
                },
                icon: const Icon(Icons.place_outlined),
                label: const Text('장소 보러가기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentLight,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _collectionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("오류 발생: ${snapshot.error}"));
                  } else {
                    final collections = snapshot.data ?? [];
                    if (collections.isEmpty) {
                      return const Center(child: Text("저장된 컬렉션이 없습니다."));
                    }
                    return ListView.builder(
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final coll = collections[index];
                        final collName = coll['collection_name'] ?? '이름 없음';
                        // 기존 ListTile의 onTap 콜백을 아래와 같이 수정합니다.
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.collections, color: Colors.white),
                          ),
                          title: Text(collName),
                          onTap: () {
                            // 선택한 컬렉션 데이터를 반환합니다.
                            Navigator.pop(context, coll);
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
