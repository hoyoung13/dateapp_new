import 'dart:convert';
import 'package:date/AIcourse2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'category.dart'; // mainCategories, subCategories 를 제공
import 'dart:io';
import 'theme_colors.dart';

import 'constants.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'schedule_item.dart';
import 'user_provider.dart';
import 'AIcourse2.dart';

class AICoursePage extends StatefulWidget {
  const AICoursePage({Key? key}) : super(key: key);

  @override
  State<AICoursePage> createState() => _AICoursePageState();
}

class _AICoursePageState extends State<AICoursePage> {
  // 1) 지역 데이터

  Map<String, dynamic> regionData = {};
  String? selectedCity;
  String? selectedDistrict;
  String? selectedNeighborhood;

  // 2) 일정별 선택 정보 (메인/서브 카테고리, travelInfo, maxDistance)
  List<ScheduleItem> schedules = [
    ScheduleItem(), // 첫 번째 일정
  ];

  // 3) Stepper 대신 리스트 형태로 직접 렌더링 중(간단화를 위해 Stepper 제거)
  //   → currentStep 는 더 이상 사용하지 않음

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final jsonStr = await rootBundle.loadString('assets/regions.json');
    setState(() => regionData = json.decode(jsonStr));
  }

  void _addSchedule() {
    setState(() {
      schedules.add(ScheduleItem());
    });
  }

  void _removeSchedule(int idx) {
    if (schedules.length <= 1) return;
    setState(() {
      schedules.removeAt(idx);
    });
  }

  /// “카테고리 선택” 모달
  void _openCategoryDialog(int idx) {
    String? selMain = schedules[idx].mainCategory;
    String? selSub = schedules[idx].subCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16),
        child: StatefulBuilder(builder: (ctx, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('카테고리 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // ─── 메인 카테고리 ───────────────────────────
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mainCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final cat = mainCategories[i];
                    final isSel = cat.label == selMain;
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {
                          selMain = cat.label;
                          selSub = null;
                        });
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.appBar : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat.icon,
                                color: isSel ? Colors.white : Colors.black),
                            const SizedBox(height: 4),
                            Text(cat.label,
                                style: TextStyle(
                                    color:
                                        isSel ? Colors.white : Colors.black)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ─── 서브 카테고리 ───────────────────────────
              if (selMain == null)
                const Text('먼저 메인 카테고리를 선택해주세요.',
                    style: TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: subCategories[selMain!]!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, j) {
                      final sub = subCategories[selMain!]![j];
                      final isSel = sub == selSub;
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          selSub = sub;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? Colors.pink : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(sub,
                              style: TextStyle(
                                  color: isSel ? Colors.white : Colors.black)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: (selMain != null && selSub != null)
                    ? () {
                        setState(() {
                          schedules[idx].mainCategory = selMain;
                          schedules[idx].subCategory = selSub;
                        });
                        Navigator.of(ctx).pop();
                      }
                    : null,
                child: const Text('확인'),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// 실제 “AI 코스 추천받기” 누를 때 호출
  // aicourse_controller.dart (Flutter)
  Future<void> _submitAICourse() async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) {/* 로그인 필요 */}

    final payload = {
      'user_id': userId,
      'city': selectedCity,
      'district': selectedDistrict,
      'neighborhood': selectedNeighborhood,
      'schedules': schedules.map((s) => s.toJson()).toList(),
    };

    final resp = await http.post(
      Uri.parse('$BASE_URL/aicourse/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    print('▶ AI 추천 응답: ${resp.body}');

    if (resp.statusCode == 200) {
      final bodyJson = json.decode(resp.body) as Map<String, dynamic>;
      if (bodyJson['success'] == true) {
        final List<dynamic> courseJson = bodyJson['course'] as List<dynamic>;
        List<ScheduleItem> recommended = courseJson.map((item) {
          if (item == null) return ScheduleItem(); // 추천 없음
          return ScheduleItem.fromJson(item as Map<String, dynamic>);
        }).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AICourse2Page(
              courseName: "ㅇㅇ", // 사용자가 입력한 코스명
              courseDescription: "ㅇㅇ", // 사용자가 입력한 설명
              schedules: recommended,
            ),
          ),
        );
      } else {
        // error handling
      }
    } else {
      // statusCode != 200 일 때 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 추천 코스 제작'),
        backgroundColor: AppColors.accentLight,
        iconTheme: const IconThemeData(color: Colors.black),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── 1) 지역 설정 ─────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    hint: '시/도',
                    value: selectedCity,
                    items: regionData.keys.toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedCity = v;
                        selectedDistrict = null;
                        selectedNeighborhood = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    hint: '구/군',
                    value: selectedDistrict,
                    items: selectedCity != null
                        ? List<String>.from(regionData[selectedCity]!.keys)
                        : [],
                    onChanged: (v) => setState(() => selectedDistrict = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    hint: '동/읍/면',
                    value: selectedNeighborhood,
                    items: (selectedCity != null && selectedDistrict != null)
                        ? List<String>.from(
                            regionData[selectedCity]![selectedDistrict]!)
                        : [],
                    onChanged: (v) => setState(() => selectedNeighborhood = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 2) 일정별 카테고리 + 거리 설정 ─────────────────
            Expanded(
              child: ListView(
                children: [
                  for (int i = 0; i < schedules.length; i++) ...[
                    Text(
                      "${i + 1}번째 일정",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // (1) 카테고리 선택 버튼
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: InkWell(
                              onTap: () => _openCategoryDialog(i),
                              child: Center(
                                child: Text(
                                  schedules[i].mainCategory == null
                                      ? "카테고리 선택"
                                      : "${schedules[i].mainCategory} > ${schedules[i].subCategory}",
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
                                const SnackBar(
                                  content: Text("최소 한 개의 일정이 필요합니다."),
                                ),
                              );
                            } else {
                              setState(() => schedules.removeAt(i));
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // (2) 이전 일정과의 최대 거리 선택 드롭다운
                    if (i > 0) // 첫 번째 일정(i=0) 은 거리 선택 없음
                      DropdownButtonFormField<String>(
                        value: schedules[i].maxDistance,
                        hint: const Text('이전 일정과의 최대 거리'),
                        items: [
                          '1km 이내',
                          '2km 이내',
                          '3km 이내',
                          '5km 이내',
                          '10km 이내',
                        ].map((dist) {
                          return DropdownMenuItem<String>(
                            value: dist,
                            child: Text(dist),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            schedules[i].maxDistance = v;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),

                    const SizedBox(height: 16),
                  ],

                  // (3) 일정 추가 버튼
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addSchedule,
                      icon: const Icon(Icons.add, color: AppColors.appBar),
                      label: const Text(
                        "일정 추가하기",
                        style: TextStyle(color: AppColors.appBar),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.appBar),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── 3) 생성 완료 버튼 ────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAICourse,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('AI 코스 추천받기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// 각 일정의 상태를 담는 모델
class _ScheduleItem {
  String? mainCategory;
  String? subCategory;
  String? travelInfo; // 예: “도보 10분”
  String? maxDistance; // 예: “1km 이내”
}
