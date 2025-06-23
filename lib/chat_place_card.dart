import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'foodplace.dart';

/// Card widget for displaying a shared place inside chat.
/// It fetches the place info from `/places/:id`.
class ChatPlaceCard extends StatelessWidget {
  final int placeId;
  final String fallbackText;
  const ChatPlaceCard({
    Key? key,
    required this.placeId,
    required this.fallbackText,
  }) : super(key: key);

  Future<Map<String, dynamic>?> _fetch() async {
    try {
      final resp = await http.get(Uri.parse('$BASE_URL/places/$placeId'));
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) {
          // API may wrap the place inside a 'place' key
          if (decoded.containsKey('place')) {
            final p = decoded['place'];
            if (p is Map<String, dynamic>) return p;
          } else {
            return decoded;
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          // 실패 시 기본 텍스트 보여주기
          return Text(fallbackText);
        }
        final place = snapshot.data!;
        final List<dynamic> images =
            place['images'] is List ? List<dynamic>.from(place['images']) : [];
        String imgUrl = images.isNotEmpty ? images.first.toString() : '';
        ImageProvider? provider;
        if (imgUrl.isNotEmpty) {
          if (imgUrl.startsWith('http')) {
            provider = NetworkImage(imgUrl);
          } else if (imgUrl.startsWith('/data/') ||
              imgUrl.startsWith('file://')) {
            provider = FileImage(File(imgUrl));
          } else {
            provider = NetworkImage('$BASE_URL$imgUrl');
          }
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceInPageUIOnly(payload: place),
              ),
            );
          },
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                provider != null
                    ? Image(
                        image: provider,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['place_name']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (place['address'] != null)
                        Text(
                          place['address'].toString(),
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
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
}
