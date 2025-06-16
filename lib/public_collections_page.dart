import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'zzimdetail.dart';
import 'dart:io';

class PublicCollectionsPage extends StatefulWidget {
  const PublicCollectionsPage({Key? key}) : super(key: key);

  @override
  _PublicCollectionsPageState createState() => _PublicCollectionsPageState();
}

class _PublicCollectionsPageState extends State<PublicCollectionsPage> {
  late Future<List<dynamic>> _collectionsFuture;
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

    DecorationImage? bg;
    if (thumb.isNotEmpty) {
      ImageProvider provider;
      if (thumb.startsWith('http')) {
        provider = NetworkImage(thumb);
      } else if (thumb.startsWith('/data/') || thumb.startsWith('file://')) {
        provider = FileImage(File(thumb));
      } else {
        provider = NetworkImage('$BASE_URL$thumb');
      }
      bg = DecorationImage(image: provider, fit: BoxFit.cover);
    }

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
            width: 50,
            height: 50,
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
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(color: Colors.white),
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
                        style: const TextStyle(color: Colors.white, shadows: [
                          Shadow(blurRadius: 2, color: Colors.black)
                        ]),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.favorite_border, color: Colors.white),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 60,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 컬렉션'),
        backgroundColor: Colors.cyan[100],
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _collectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final collections = snapshot.data ?? [];
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
