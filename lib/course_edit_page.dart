import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'theme_colors.dart';
import 'constants.dart';
import 'schedule_item.dart';
import 'user_provider.dart';
import 'zzimlist.dart';
import 'selectplace.dart';

class CourseEditPage extends StatefulWidget {
  final CourseModel course;
  const CourseEditPage({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _courseDescController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  DateTime? _selectedDate;
  List<String> hashtags = [];
  List<ScheduleItem> schedules = [];

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
    final c = widget.course;
    _courseNameController.text = c.courseName;
    _courseDescController.text = c.courseDescription;
    hashtags = List<String>.from(c.hashtags);
    _selectedDate = c.selectedDate;
    schedules = c.schedules
        .map((s) => ScheduleItem(
              placeId: s.placeId,
              placeName: s.placeName,
              placeAddress: s.placeAddress,
              placeImage: s.placeImage,
            ))
        .toList();
    if (schedules.isEmpty) schedules.add(ScheduleItem());
    withWhoSelected = withWhoOptions.map((o) => c.withWho.contains(o)).toList();
    purposeSelected = purposeOptions.map((o) => c.purpose.contains(o)).toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (selected != null) {
      setState(() {
        _selectedDate = selected;
      });
    }
  }

  void _addHashtag() {
    final text = _hashtagController.text.trim();
    if (text.isNotEmpty && !hashtags.contains(text)) {
      setState(() {
        hashtags.add(text);
      });
    }
    _hashtagController.clear();
  }

  void _removeHashtag(String tag) {
    setState(() {
      hashtags.remove(tag);
    });
  }

  void _addSchedule() {
    setState(() {
      schedules.add(ScheduleItem());
    });
  }

  Future<void> _openZzimDialog(int idx) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인 정보가 없습니다.')));
      return;
    }

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ZzimListDialog(userId: userId),
    );
    if (result == null) return;

    if (result.containsKey('place_name')) {
      setState(() {
        schedules[idx].placeId = result['id']?.toString();
        schedules[idx].placeName = result['place_name'];
        schedules[idx].placeAddress = result['address'];
        schedules[idx].placeImage = result['image'];
      });
      return;
    }

    final Map<String, dynamic>? selectedPlace =
        await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectplacePage(collection: result),
      ),
    );
    if (selectedPlace == null) return;

    setState(() {
      schedules[idx].placeId = selectedPlace['id']?.toString();
      schedules[idx].placeName = selectedPlace['place_name'];
      schedules[idx].placeAddress = selectedPlace['address'];
      schedules[idx].placeImage = selectedPlace['image'];
    });
  }

  Future<void> _updateCourse() async {
    final selectedWithWho = <String>[];
    for (int i = 0; i < withWhoOptions.length; i++) {
      if (withWhoSelected[i]) selectedWithWho.add(withWhoOptions[i]);
    }
    final selectedPurpose = <String>[];
    for (int i = 0; i < purposeOptions.length; i++) {
      if (purposeSelected[i]) selectedPurpose.add(purposeOptions[i]);
    }

    final payload = {
      'course_name': _courseNameController.text,
      'course_description': _courseDescController.text,
      'hashtags': hashtags,
      'selected_date': _selectedDate?.toIso8601String(),
      'with_who': selectedWithWho,
      'purpose': selectedPurpose,
      'schedules': schedules.map((e) => e.toCourseJson()).toList(),
    };

    final url = Uri.parse('$BASE_URL/course/courses/${widget.course.id}');
    try {
      final resp = await http.put(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload));
      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('코스 수정 완료!')));
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: ${resp.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

  Widget _buildSelectedPlaceCard(ScheduleItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.placeImage != null)
              item.placeImage!.startsWith('http')
                  ? Image.network(
                      item.placeImage!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(item.placeImage!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
            else
              Container(
                color: Colors.grey.shade300,
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                child: const Text('이미지 없음'),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.placeName ?? '장소 이름 없음',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.placeAddress ?? '주소 정보 없음',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('코스 수정하기'),
        backgroundColor: AppColors.accentLight,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이름 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _courseNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('코스 설명',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _courseDescController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('해시태그',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagController,
                    decoration: InputDecoration(
                      hintText: '해시태그 입력',
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(onPressed: _addHashtag, icon: const Icon(Icons.add)),
              ],
            ),
            if (hashtags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hashtags
                    .map((tag) => Chip(
                          label: Text('#$tag'),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () => _removeHashtag(tag),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            const Text('날짜 설정 (미설정 가능)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickDate,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentLight),
                  child: Text(
                    _selectedDate == null
                        ? '날짜 선택'
                        : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < schedules.length; i++) ...[
              Text('${i + 1}번째 일정',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: InkWell(
                        onTap: () => _openZzimDialog(i),
                        child: Center(
                          child: Text(
                            schedules[i].placeName == null ? '장소 선택' : '장소 변경',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      if (schedules.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('최소 한 개의 일정이 필요합니다.')),
                        );
                      } else {
                        setState(() {
                          schedules.removeAt(i);
                        });
                      }
                    },
                  ),
                ],
              ),
              if (schedules[i].placeName != null)
                _buildSelectedPlaceCard(schedules[i]),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addSchedule,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.appBar),
                  foregroundColor: AppColors.appBar,
                ),
                icon: const Icon(Icons.add),
                label: const Text('일정 추가하기'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('누구랑 가는 코스인가요? (최소 1개 이상)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(withWhoOptions.length, (index) {
                return ChoiceChip(
                  label: Text(withWhoOptions[index]),
                  selected: withWhoSelected[index],
                  onSelected: (selected) {
                    setState(() {
                      withWhoSelected[index] = selected;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            const Text('무엇을 하러 가는 코스인가요? (최소 1개 이상)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(purposeOptions.length, (index) {
                return ChoiceChip(
                  label: Text(purposeOptions[index]),
                  selected: purposeSelected[index],
                  onSelected: (selected) {
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
                onPressed: _updateCourse,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentLight),
                child:
                    const Text('코스 수정', style: TextStyle(color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
