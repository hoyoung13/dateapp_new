import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'foodplace.dart';
import 'theme_colors.dart';

class FullRankingPage extends StatefulWidget {
  final String title;
  final String? category;

  const FullRankingPage({Key? key, required this.title, this.category})
      : super(key: key);

  @override
  State<FullRankingPage> createState() => _FullRankingPageState();
}

class _FullRankingPageState extends State<FullRankingPage> {
  List<Map<String, dynamic>>? rankingData;

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    setState(() {
      rankingData = null; // loading
    });
    try {
      Uri uri;
      if (widget.category == null) {
        uri = Uri.parse('$BASE_URL/places/places/top/week?limit=50');
      } else {
        final encoded = Uri.encodeComponent(widget.category!);
        uri = Uri.parse(
            '$BASE_URL/places/places/top/week?limit=50&category=$encoded');
      }
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          rankingData = List<Map<String, dynamic>>.from(data['places']);
        });
      } else {
        setState(() {
          rankingData = [];
        });
      }
    } catch (e) {
      setState(() {
        rankingData = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.accentLight,
        foregroundColor: Colors.black,
      ),
      body: rankingData == null
          ? const Center(child: CircularProgressIndicator())
          : rankingData!.isEmpty
              ? const Center(child: Text('데이터가 없습니다.'))
              : ListView.separated(
                  itemCount: rankingData!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildRankingTile(rankingData![index], index);
                  },
                ),
    );
  }

  Widget _buildRankingTile(Map<String, dynamic> place, int index) {
    final List<dynamic> images =
        place['images'] is List ? List<dynamic>.from(place['images']) : [];
    String imageUrl = '';
    if (images.isNotEmpty) {
      imageUrl = images.first.toString();
    }
    final String placeName = place['place_name'] ?? '이름 없음';

    Widget imageWidget;
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        imageWidget = Image.network(
          imageUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      } else {
        imageWidget = Image.file(
          File(imageUrl),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      }
    } else {
      imageWidget = Container(
        width: 60,
        height: 60,
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported),
      );
    }

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceInPageUIOnly(payload: place),
          ),
        );
      },
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageWidget,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.black54,
              child: Text(
                '#${index + 1}',
                style: const TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      title: Text(placeName),
    );
  }
}
