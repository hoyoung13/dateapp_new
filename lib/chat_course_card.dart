import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'course_detail_loader.dart';
import 'schedule_item.dart';

/// Simple card widget for showing a shared course inside chat.
class ChatCourseCard extends StatelessWidget {
  final int courseId;
  const ChatCourseCard({Key? key, required this.courseId}) : super(key: key);

  Future<CourseModel?> _fetch() async {
    final resp =
        await http.get(Uri.parse('$BASE_URL/course/courses/$courseId'));
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body) as Map<String, dynamic>;
      final map = decoded['course'] as Map<String, dynamic>?;
      if (map != null) {
        return CourseModel.fromJson(map);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CourseModel?>(
      future: _fetch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
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
        final course = snapshot.data!;
        final first =
            course.schedules.isNotEmpty ? course.schedules.first : null;
        Widget imageWidget;
        if (first?.placeImage != null && first!.placeImage!.isNotEmpty) {
          var img = first.placeImage!;
          if (img.startsWith('http')) {
            imageWidget =
                Image.network(img, width: 80, height: 80, fit: BoxFit.cover);
          } else if (img.startsWith('/data/') || img.startsWith('file://')) {
            imageWidget =
                Image.file(File(img), width: 80, height: 80, fit: BoxFit.cover);
          } else {
            imageWidget = Image.network('$BASE_URL$img',
                width: 80, height: 80, fit: BoxFit.cover);
          }
        } else {
          imageWidget = Container(
            width: 80,
            height: 80,
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported),
          );
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CourseDetailLoaderPage(courseId: courseId)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageWidget,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.courseName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (first?.placeName != null)
                        Text(first!.placeName!,
                            style: const TextStyle(fontSize: 12)),
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
