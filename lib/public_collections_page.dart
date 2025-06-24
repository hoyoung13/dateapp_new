import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'zzimdetail.dart';
import 'dart:io';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'theme_colors.dart';

class PublicCollectionsPage extends StatefulWidget {
  const PublicCollectionsPage({Key? key}) : super(key: key);

  @override
  _PublicCollectionsPageState createState() => _PublicCollectionsPageState();
}

class _PublicCollectionsPageState extends State<PublicCollectionsPage> {
  late Future<List<dynamic>> _collectionsFuture;
  Set<int> _myCollectionIds = {}; // 내 컬렉션 ID 목록

  Future<List<dynamic>> fetchPlacesInCollection(int collectionId) async {
    final url = Uri.parse('$BASE_URL/zzim/collection_places/$collectionId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['places'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('fetchPlacesInCollection error: $e');
    }
    return [];
  }

  Widget _buildCollectionCard(dynamic coll) {
    final thumb = coll['thumbnail']?.toString() ?? '';
    final nickname = coll['nickname']?.toString() ?? '';
    final profile = coll['profile_image']?.toString() ?? '';

    ImageProvider? profileProvider;
    if (profile.isNotEmpty) {
      if (profile.startsWith('http')) {
        profileProvider = NetworkImage(profile);
      } else if (profile.startsWith('/data/') ||
          profile.startsWith('file://')) {
        profileProvider = FileImage(File(profile));
      } else {
        profileProvider = NetworkImage('$BASE_URL$profile');
      }
    }

    return FutureBuilder<List<dynamic>>(
      future: fetchPlacesInCollection(coll['id'] as int),
      builder: (context, snapshot) {
        final places = snapshot.data ?? [];
        final display = places.take(5).toList();
        final extra = places.length - display.length;
        String bgUrl = thumb;
        if (bgUrl.isEmpty && places.isNotEmpty) {
          final first = places.first;
          final List<dynamic> imgs = first['images'] is List
              ? List<dynamic>.from(first['images'])
              : [];
          if (imgs.isNotEmpty) {
            bgUrl = imgs.first.toString();
          }
        }

        DecorationImage? bg;
        if (bgUrl.isNotEmpty) {
          ImageProvider provider;
          if (bgUrl.startsWith('http')) {
            provider = NetworkImage(bgUrl);
          } else if (bgUrl.startsWith('/data/') ||
              bgUrl.startsWith('file://')) {
            provider = FileImage(File(bgUrl));
          } else {
            provider = NetworkImage('$BASE_URL$bgUrl');
          }
          bg = DecorationImage(image: provider, fit: BoxFit.cover);
        }
        List<Widget> placeImages = [];
        for (var i = 0; i < display.length; i++) {
          final place = display[i];
          final List<dynamic> images = place['images'] is List
              ? List<dynamic>.from(place['images'])
              : [];
          String imgUrl = images.isNotEmpty ? images.first.toString() : '';
          ImageProvider provider;
          if (imgUrl.startsWith('http')) {
            provider = NetworkImage(imgUrl);
          } else if (imgUrl.startsWith('/data/') ||
              imgUrl.startsWith('file://')) {
            provider = FileImage(File(imgUrl));
          } else {
            provider = NetworkImage('$BASE_URL$imgUrl');
          }
          Widget img = Container(
            margin: const EdgeInsets.only(right: 4),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(image: provider, fit: BoxFit.cover),
            ),
          );
          if (extra > 0 && i == display.length - 1) {
            img = Stack(
              children: [
                img,
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(color: Colors.black),
                  ),
                )
              ],
            );
          }
          placeImages.add(img);
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(collection: coll)),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              image: bg,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: profileProvider,
                        child: profileProvider == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        nickname,
                        style: const TextStyle(color: Colors.black, shadows: [
                          Shadow(blurRadius: 2, color: Colors.black)
                        ]),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _myCollectionIds.contains(coll['id'])
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.white,
                        ),
                        onPressed: _myCollectionIds.contains(coll['id'])
                            ? null
                            : () => _favoriteCollection(coll),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: 8,
                  right: 8,
                  child: Text(
                    coll['collection_name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Row(children: placeImages),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _collectionsFuture = _fetchPublicCollections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMyCollections();
    });
  }

  Future<List<dynamic>> _fetchPublicCollections() async {
    try {
      final resp =
          await http.get(Uri.parse('$BASE_URL/zzim/public_collections'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['collections'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('fetchPublicCollections error: $e');
    }
    return [];
  }

  Future<void> _fetchMyCollections() async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;
    try {
      final resp =
          await http.get(Uri.parse('$BASE_URL/zzim/collections/$userId'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final List<dynamic> collections = data['collections'] ?? [];
        setState(() {
          _myCollectionIds = collections
              .map((e) => e['copied_from_id'] ?? e['id'])
              .map((id) => id is int ? id : int.parse(id.toString()))
              .toSet();
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _favoriteCollection(Map<String, dynamic> coll) async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;
    final collId = coll['id'];
    if (collId == null || _myCollectionIds.contains(collId)) return;
    final url = Uri.parse('$BASE_URL/zzim/collections');
    final body = {
      'user_id': userId,
      'collection_name': coll['collection_name'],
      'description': coll['description'],
      'thumbnail': coll['thumbnail'],
      'is_public': false,
      'favorite_from_collection_id': collId,
    };
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (resp.statusCode == 201) {
        setState(() {
          _myCollectionIds
              .add(collId is int ? collId : int.parse(collId.toString()));
        });
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

  List<dynamic> filterCollections(List<dynamic> collections, int? userId) {
    if (userId == null) return collections;
    return collections.where((c) => c['user_id'] != userId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 컬렉션'),
        backgroundColor: AppColors.accentLight,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _collectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final userId =
              Provider.of<UserProvider>(context, listen: false).userId;
          final collections = filterCollections(snapshot.data ?? [], userId);
          if (collections.isEmpty) {
            return const Center(child: Text('공개된 컬렉션이 없습니다.'));
          }
          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final coll = collections[index];
              return _buildCollectionCard(coll);
            },
          );
        },
      ),
    );
  }
}
