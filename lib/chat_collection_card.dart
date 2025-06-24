import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'theme_colors.dart';
import 'constants.dart';
import 'zzimdetail.dart';

class ChatCollectionCard extends StatelessWidget {
  final int collectionId;
  final int senderId;
  const ChatCollectionCard({
    Key? key,
    required this.collectionId,
    required this.senderId,
  }) : super(key: key);

  Future<Map<String, dynamic>?> _fetch() async {
    try {
      final collResp =
          await http.get(Uri.parse('$BASE_URL/zzim/collections/$senderId'));
      if (collResp.statusCode == 200) {
        final decoded = json.decode(collResp.body) as Map<String, dynamic>;
        final colls = decoded['collections'] as List<dynamic>?;
        if (colls != null) {
          final coll = colls.cast<Map<String, dynamic>>().firstWhere(
                (c) => c['id'] == collectionId,
                orElse: () => <String, dynamic>{},
              );
          if (coll.isNotEmpty) {
            final placeResp = await http.get(
                Uri.parse('$BASE_URL/zzim/collection_places/$collectionId'));
            List<dynamic> places = [];
            if (placeResp.statusCode == 200) {
              final pDecoded =
                  json.decode(placeResp.body) as Map<String, dynamic>;
              places = pDecoded['places'] as List<dynamic>? ?? [];
            }
            return {'collection': coll, 'places': places};
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox(
              height: 100,
              width: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final data = snapshot.data!;
        final coll = data['collection'] as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>;

        final thumb = coll['thumbnail']?.toString() ?? '';
        final nickname = coll['nickname']?.toString() ?? '';
        final profile = coll['profile_image']?.toString() ?? '';
        final collName = coll['collection_name']?.toString() ?? '';

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
            margin: const EdgeInsets.only(right: 2),
            width: 40,
            height: 40,
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
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(color: Colors.black, fontSize: 12),
                  ),
                )
              ],
            );
          }
          placeImages.add(img);
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CollectionDetailPage(collection: coll),
              ),
            );
          },
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              image: bg,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: profileProvider,
                        child: profileProvider == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          nickname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            shadows: [
                              Shadow(blurRadius: 2, color: Colors.black)
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 56,
                  left: 8,
                  right: 8,
                  child: Text(
                    collName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Row(children: placeImages),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
