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
              final thumb = coll['thumbnail']?.toString() ?? '';
              Widget leading;
              if (thumb.isNotEmpty) {
                if (thumb.startsWith('http')) {
                  leading = Image.network(thumb,
                      width: 40, height: 40, fit: BoxFit.cover);
                } else if (thumb.startsWith('/data/') ||
                    thumb.startsWith('file://')) {
                  leading = Image.file(File(thumb),
                      width: 40, height: 40, fit: BoxFit.cover);
                } else {
                  leading = Image.network('$BASE_URL$thumb',
                      width: 40, height: 40, fit: BoxFit.cover);
                }
              } else {
                leading = const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.collections, color: Colors.white),
                );
              }
              return ListTile(
                leading: leading,
                title: Text(coll['collection_name'] ?? ''),
                subtitle: Text(coll['nickname'] ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CollectionDetailPage(collection: coll)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
