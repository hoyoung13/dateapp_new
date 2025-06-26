import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'zzim.dart';
import 'foodplace.dart';
import 'dart:io';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'theme_colors.dart';

class CollectionDetailPage extends StatefulWidget {
  final Map<String, dynamic> collection;

  const CollectionDetailPage({Key? key, required this.collection})
      : super(key: key);
  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late Map<String, dynamic> collection;
  Future<List<dynamic>>? _placesFuture;

  @override
  void initState() {
    super.initState();
    collection = Map<String, dynamic>.from(widget.collection);
    final int? id = collection['id'];
    if (id != null) {
      _placesFuture = fetchPlacesInCollection(id);
    }
  }

  // 컬렉션 내 장소 목록 불러오기
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

  // 컬렉션 삭제
  Future<void> _deleteCollection(BuildContext context, int collectionId) async {
    final url = Uri.parse('$BASE_URL/zzim/collections/$collectionId');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('컬렉션 삭제 성공: $data');
        Navigator.pop(context);
      } else {
        print('컬렉션 삭제 실패: ${response.statusCode} ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: ${response.statusCode}')),
        );
      }
    } catch (error) {
      print('Error deleting collection: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 오류로 삭제에 실패했습니다.')),
      );
    }
  }

  Future<void> _updateCollection(
      BuildContext context, int id, String name, String desc) async {
    final url = Uri.parse('$BASE_URL/zzim/collections/$id');
    try {
      final resp = await http.patch(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'collection_name': name,
            'description': desc,
          }));
      if (resp.statusCode == 200) {
        setState(() {
          collection['collection_name'] = name;
          collection['description'] = desc;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: ${resp.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('서버 오류')));
    }
  }

  Future<void> _favoriteCollection() async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;
    final collId = collection['id'];
    if (collId == null) return;
    final url = Uri.parse('$BASE_URL/zzim/collections/$collId/favorite');
    final body = {
      'user_id': userId,
    };
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 컬렉션에 저장되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  void _showShareDialogForCollection(int collectionId, String name) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final nickname = userProvider.nickname ?? '';
    if (userId == null) return;

    Future<List<dynamic>> fetchFriends() async {
      final resp = await http.get(Uri.parse('$BASE_URL/fri/friends/$userId'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['friends'] as List<dynamic>;
      }
      return [];
    }

    Future<List<dynamic>> fetchRooms() async {
      final resp =
          await http.get(Uri.parse('$BASE_URL/chat/rooms/user/$userId'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['rooms'] as List<dynamic>;
      }
      return [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: 400,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(tabs: [Tab(text: '친구'), Tab(text: '채팅')]),
                Expanded(
                  child: TabBarView(
                    children: [
                      FutureBuilder<List<dynamic>>(
                        future: fetchFriends(),
                        builder: (c, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final friends = snap.data ?? [];
                          if (friends.isEmpty) {
                            return const Center(child: Text('친구가 없습니다.'));
                          }
                          return ListView.builder(
                            itemCount: friends.length,
                            itemBuilder: (c, i) {
                              final f = friends[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: f['profile_image'] != null &&
                                          f['profile_image']
                                              .toString()
                                              .isNotEmpty
                                      ? NetworkImage(f['profile_image'])
                                      : null,
                                  child: (f['profile_image'] == null ||
                                          f['profile_image'].toString().isEmpty)
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(f['nickname'] ?? ''),
                                onTap: () async {
                                  final createResp = await http.post(
                                    Uri.parse('$BASE_URL/chat/rooms/1on1'),
                                    headers: {
                                      'Content-Type': 'application/json'
                                    },
                                    body: json.encode(
                                        {'userA': userId, 'userB': f['id']}),
                                  );
                                  if (createResp.statusCode == 200) {
                                    final roomId =
                                        json.decode(createResp.body)['roomId'];
                                    final sendResp = await http.post(
                                      Uri.parse(
                                          '$BASE_URL/chat/rooms/$roomId/messages'),
                                      headers: {
                                        'Content-Type': 'application/json'
                                      },
                                      body: json.encode({
                                        'sender_id': userId,
                                        'type': 'collection',
                                        'collection_id': collectionId,
                                        'content':
                                            '${nickname}님이 ${name} 콜렉션을 공유했습니다.',
                                      }),
                                    );
                                    if (sendResp.statusCode == 200 ||
                                        sendResp.statusCode == 201) {
                                      Navigator.of(ctx).pop();
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('콜렉션을 공유하였습니다.')),
                                      );
                                      print(
                                          'Failed to send collection: ${sendResp.statusCode} ${sendResp.body}');
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('콜렉션 공유 실패')),
                                    );
                                    print(
                                        'Failed to create room: ${createResp.statusCode} ${createResp.body}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                      FutureBuilder<List<dynamic>>(
                        future: fetchRooms(),
                        builder: (c, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final rooms = snap.data ?? [];
                          if (rooms.isEmpty) {
                            return const Center(child: Text('채팅방이 없습니다.'));
                          }
                          return ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (c, i) {
                              final r = rooms[i];
                              return ListTile(
                                title: Text(r['room_name'] ?? ''),
                                onTap: () async {
                                  final roomId = r['room_id'];
                                  final resp = await http.post(
                                    Uri.parse(
                                        '$BASE_URL/chat/rooms/$roomId/messages'),
                                    headers: {
                                      'Content-Type': 'application/json'
                                    },
                                    body: json.encode({
                                      'sender_id': userId,
                                      'type': 'collection',
                                      'collection_id': collectionId,
                                      'content':
                                          '${nickname}님이 ${name} 콜렉션을 공유했습니다.',
                                    }),
                                  );
                                  if (resp.statusCode == 200 ||
                                      resp.statusCode == 201) {
                                    Navigator.of(ctx).pop();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('콜렉션 공유 실패')),
                                    );
                                    print(
                                        'Failed to share collection to room $roomId: ${resp.statusCode} ${resp.body}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePlace(
      BuildContext context, int collectionId, int placeId) async {
    final url =
        Uri.parse('$BASE_URL/zzim/collection_places/$collectionId/$placeId');
    try {
      final resp = await http.delete(url);
      if (resp.statusCode == 200) {
        setState(() {
          _placesFuture = fetchPlacesInCollection(collectionId);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: ${resp.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('서버 오류')));
    }
  }

  void _showEditDialog(int id) {
    final nameCtrl =
        TextEditingController(text: collection['collection_name'] ?? '');
    final descCtrl =
        TextEditingController(text: collection['description'] ?? '');
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('콜렉션 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '설명'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateCollection(
                    context, id, nameCtrl.text, descCtrl.text);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPublic = collection['is_public'] == true;
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    final dynamic owner = collection['user_id'];
    final bool isOwner = owner != null &&
        userId != null &&
        owner.toString() == userId.toString();
    // created_at → "YYYY-MM-DD"
    String creationDate = '';
    if (collection['created_at'] != null) {
      try {
        final dt = DateTime.parse(collection['created_at']);
        creationDate =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (e) {}
    }

    final int? collectionId = collection['id'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        elevation: 0,
        title: Text(
          collection['collection_name'] ?? '컬렉션 상세',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 공개/비공개 + 제목
            Row(
              children: [
                Text(
                  isPublic ? '공개' : '비공개',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  collection['collection_name'] ?? '제목 없음',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 생성일
            Text(
              creationDate.isEmpty ? '' : creationDate,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // 설명
            Text(
              collection['description'] ?? '설명이 없습니다.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // 편집/공유/삭제 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isOwner) ...[
                  InkWell(
                    onTap: () {
                      if (collectionId != null) _showEditDialog(collectionId);
                    },
                    child: Column(
                      children: const [
                        Icon(Icons.edit, color: Colors.black),
                        SizedBox(height: 4),
                        Text('편집',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (collectionId != null) {
                        _showShareDialogForCollection(
                            collectionId, collection['collection_name'] ?? '');
                      }
                    },
                    child: Column(
                      children: const [
                        Icon(Icons.share, color: Colors.black),
                        SizedBox(height: 4),
                        Text('공유',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      if (collectionId == null) {
                        print('컬렉션 ID가 없습니다. 삭제 불가');
                        return;
                      }
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('정말 삭제하시겠습니까?'),
                            content: const Text('삭제 후 복구가 불가능합니다.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          );
                        },
                      );
                      if (confirm == true) {
                        await _deleteCollection(context, collectionId);
                      }
                    },
                    child: Column(
                      children: const [
                        Icon(Icons.delete, color: Colors.black),
                        SizedBox(height: 4),
                        Text('삭제',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black)),
                      ],
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () {
                      if (collectionId != null) {
                        _showShareDialogForCollection(
                            collectionId, collection['collection_name'] ?? '');
                      }
                    },
                    child: Column(
                      children: const [
                        Icon(Icons.share, color: Colors.black),
                        SizedBox(height: 4),
                        Text('공유',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _favoriteCollection,
                    child: Column(
                      children: const [
                        Icon(Icons.favorite_border, color: Colors.black),
                        SizedBox(height: 4),
                        Text('찜',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 장소 목록 표시
            if (collectionId != null)
              Expanded(
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
                        return const Text("추가된 장소가 없습니다.");
                      }
                      // 스크롤 가능한 ListView.builder로 카드 표시
                      return ListView.builder(
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          final place = places[index];
                          return _buildPlaceCard(collectionId!, place, isOwner);
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

  /// 카드 형태로 장소 표시 (이미지, 카테고리, 장소 이름, 별점, 해시태그, 우측 하트)
  Widget _buildPlaceCard(int collectionId, dynamic place, bool isOwner) {
    // 예시 필드명 (실제 DB 구조에 맞게 수정)
    final String? imageUrl = (place['images'] != null &&
            place['images'] is List &&
            place['images'].isNotEmpty)
        ? place['images'][0].toString()
        : null;

    final String category = place['main_category'] ?? '';
    final String placeName = place['place_name'] ?? '장소 이름 없음';
    final double rating = (place['rating'] != null)
        ? double.tryParse(place['rating'].toString()) ?? 0.0
        : 0.0;
    final List<String> hashtags =
        (place['hashtags'] != null && place['hashtags'] is List)
            ? List<String>.from(place['hashtags'])
            : [];
    Widget imageWidget;
    if (imageUrl != null) {
      if (imageUrl.startsWith('http')) {
        imageWidget = Image.network(
          imageUrl,
          fit: BoxFit.cover,
          height: 180,
          width: double.infinity,
        );
      } else if (imageUrl.startsWith('/data/') ||
          imageUrl.startsWith('file://')) {
        imageWidget = Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          height: 180,
          width: double.infinity,
        );
      } else {
        final fullUrl = '$BASE_URL$imageUrl';
        imageWidget = Image.network(
          fullUrl,
          fit: BoxFit.cover,
          height: 180,
          width: double.infinity,
        );
      }
    } else {
      imageWidget = Container(
        color: Colors.grey.shade300,
        height: 180,
        width: double.infinity,
        child: const Center(child: Text('이미지 없음')),
      );
    }
    final card = Container(
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: imageWidget,
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
          // 장소 이름과 우측에 하트 아이콘 (같은 라인)
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
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('장소 삭제'),
                          content: const Text('해당 장소를 콜렉션에서 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        _deletePlace(context, collectionId, place['id']);
                      }
                    },
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceInPageUIOnly(payload: place),
          ),
        );
      },
      child: card,
    );
  }
}
