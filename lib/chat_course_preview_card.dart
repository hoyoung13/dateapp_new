import 'dart:io';
import 'package:flutter/material.dart';
import 'schedule_item.dart';
import 'coursedetail.dart';
import 'constants.dart';

/// Card widget for showing a preview of a recommended course without saving it.
class ChatCoursePreviewCard extends StatelessWidget {
  final String courseName;
  final List<dynamic> places;

  const ChatCoursePreviewCard({
    Key? key,
    required this.courseName,
    required this.places,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? first =
        places.isNotEmpty ? places.first as Map<String, dynamic> : null;
    String? img = first?['place_image']?.toString();
    String? placeName = first?['place_name']?.toString();

    ImageProvider? provider;
    if (img != null && img.isNotEmpty) {
      if (img.startsWith('http')) {
        provider = NetworkImage(img);
      } else if (img.startsWith('/data/') || img.startsWith('file://')) {
        provider = FileImage(File(img));
      } else {
        provider = NetworkImage('$BASE_URL$img');
      }
    }

    return InkWell(
      onTap: () {
        final scheduleItems = places
            .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailPage(
              courseId: 0,
              courseOwnerId: 0,
              courseName: courseName,
              courseDescription: '',
              withWho: const [],
              purpose: const [],
              hashtags: const [],
              schedules: scheduleItems,
            ),
          ),
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
                    courseName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (placeName != null)
                    Text(placeName, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
