import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'schedule_item.dart';
import 'coursedetail.dart';

class CourseDetailLoaderPage extends StatefulWidget {
  final int courseId;
  const CourseDetailLoaderPage({Key? key, required this.courseId})
      : super(key: key);

  @override
  _CourseDetailLoaderPageState createState() => _CourseDetailLoaderPageState();
}

class _CourseDetailLoaderPageState extends State<CourseDetailLoaderPage> {
  late Future<CourseModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchCourse();
  }

  Future<CourseModel?> _fetchCourse() async {
    final resp = await http
        .get(Uri.parse('$BASE_URL/course/courses/${widget.courseId}'));
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
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(
              body: Center(child: Text('코스 정보를 불러오지 못했습니다.')));
        }
        final course = snapshot.data!;
        return CourseDetailPage(
          courseId: course.id,
          courseOwnerId: course.userId,
          courseName: course.courseName,
          courseDescription: course.courseDescription,
          withWho: course.withWho,
          purpose: course.purpose,
          hashtags: course.hashtags,
          schedules: course.schedules,
        );
      },
    );
  }
}
