import 'package:flutter/material.dart';
import 'course3.dart'; // 3단계 페이지 import
import 'schedule_item.dart'; // schedule_item.dart에 정의된 ScheduleItem 사용

class CourseCreationStep2Page extends StatefulWidget {
  final String courseName;
  final String courseDescription;
  final List<ScheduleItem> schedules;

  const CourseCreationStep2Page({
    Key? key,
    required this.courseName,
    required this.courseDescription,
    required this.schedules,
  }) : super(key: key);

  @override
  _CourseCreationStep2PageState createState() =>
      _CourseCreationStep2PageState();
}

class _CourseCreationStep2PageState extends State<CourseCreationStep2Page> {
  final List<String> withWhoOptions = [
    "연인과",
    "가족과",
    "친구와",
    "나홀로",
    "반려동물과",
    "아이와",
    "부모님과",
  ];
  late List<bool> withWhoSelected;

  final List<String> purposeOptions = [
    "놀러가기",
    "데이트",
    "맛집탐방",
    "소개팅",
    "기념일",
    "차박/캠핑",
    "힐링",
    "드라이브",
    "쇼핑",
    "액티비티",
    "랜선으로",
    "생생체험",
    "문화생활",
    "공연/전시",
  ];
  late List<bool> purposeSelected;

  @override
  void initState() {
    super.initState();
    withWhoSelected = List.filled(withWhoOptions.length, false);
    purposeSelected = List.filled(purposeOptions.length, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("데이트 코스 설정하기 (2단계)"),
        backgroundColor: Colors.cyan[100],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "누구랑 가는 코스인가요? (최소 1개 이상)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(withWhoOptions.length, (index) {
                return ChoiceChip(
                  label: Text(withWhoOptions[index]),
                  selected: withWhoSelected[index],
                  onSelected: (bool selected) {
                    setState(() {
                      withWhoSelected[index] = selected;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            const Text(
              "무엇을 하러 가는 코스인가요? (최소 1개 이상)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(purposeOptions.length, (index) {
                return ChoiceChip(
                  label: Text(purposeOptions[index]),
                  selected: purposeSelected[index],
                  onSelected: (bool selected) {
                    setState(() {
                      purposeSelected[index] = selected;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.cyan[100]),
                onPressed: () {
                  final selectedWithWho = <String>[];
                  for (int i = 0; i < withWhoOptions.length; i++) {
                    if (withWhoSelected[i]) {
                      selectedWithWho.add(withWhoOptions[i]);
                    }
                  }
                  final selectedPurpose = <String>[];
                  for (int i = 0; i < purposeOptions.length; i++) {
                    if (purposeSelected[i]) {
                      selectedPurpose.add(purposeOptions[i]);
                    }
                  }
                  if (selectedWithWho.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("‘누구랑’에서 최소 1개 이상 선택해주세요.")),
                    );
                    return;
                  }
                  if (selectedPurpose.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("‘무엇을 하러’에서 최소 1개 이상 선택해주세요.")),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseCreationStep3Page(
                        courseName: widget.courseName,
                        courseDescription: widget.courseDescription,
                        withWho: selectedWithWho,
                        purpose: selectedPurpose,
                        schedules: widget.schedules,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "다음 단계",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
