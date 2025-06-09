import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:time_picker_spinner/time_picker_spinner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlaceAdditionalInfoPage extends StatefulWidget {
  final Map<String, dynamic> placeData; // 장소 검색 시 전달받은 데이터 (장소명, 주소)
  final List<Map<String, String>> priceList; // 가격 정보

  const PlaceAdditionalInfoPage({
    super.key,
    required this.placeData,
    required this.priceList,
  });

  @override
  _PlaceAdditionalInfoPageState createState() =>
      _PlaceAdditionalInfoPageState();
}

class _PlaceAdditionalInfoPageState extends State<PlaceAdditionalInfoPage> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController hashtagController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  List<String> hashtags = [];
  List<String> imageList = [];

  Map<String, bool> selectedDays = {
    "월": false,
    "화": false,
    "수": false,
    "목": false,
    "금": false,
    "토": false,
    "일": false,
  };

  Map<String, int> startHour = {
    "월": 9,
    "화": 9,
    "수": 9,
    "목": 9,
    "금": 9,
    "토": 9,
    "일": 9,
  };
  Map<String, int> startMinute = {
    "월": 0,
    "화": 0,
    "수": 0,
    "목": 0,
    "금": 0,
    "토": 0,
    "일": 0,
  };
  Map<String, int> endHour = {
    "월": 18,
    "화": 18,
    "수": 18,
    "목": 18,
    "금": 18,
    "토": 18,
    "일": 18,
  };
  Map<String, int> endMinute = {
    "월": 0,
    "화": 0,
    "수": 0,
    "목": 0,
    "금": 0,
    "토": 0,
    "일": 0,
  };

  void _toggleDaySelection(String day) {
    setState(() {
      selectedDays[day] = !selectedDays[day]!;
    });
  }

  void _showSpinnerTimePicker(BuildContext context, String day, bool isStart) {
    DateTime tempDateTime = DateTime(
      2023,
      1,
      1,
      isStart ? startHour[day]! : endHour[day]!,
      isStart ? startMinute[day]! : endMinute[day]!,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("시간 설정"),
          content: SizedBox(
            height: 200,
            child: TimePickerSpinner(
              is24HourMode: true,
              normalTextStyle:
                  const TextStyle(fontSize: 18, color: Colors.grey),
              highlightedTextStyle:
                  const TextStyle(fontSize: 24, color: Colors.black),
              spacing: 40,
              itemHeight: 40,
              isForce2Digits: true,
              time: tempDateTime,
              onTimeChange: (newTime) {
                tempDateTime = newTime;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (isStart) {
                    startHour[day] = tempDateTime.hour;
                    startMinute[day] = tempDateTime.minute;
                  } else {
                    endHour[day] = tempDateTime.hour;
                    endMinute[day] = tempDateTime.minute;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text("확인"),
            ),
          ],
        );
      },
    );
  }

  void _addHashtag() {
    String text = hashtagController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!text.startsWith('#')) {
          text = "#$text";
        }
        hashtags.add(text);
        hashtagController.clear();
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imageList.add(pickedFile.path);
      });
    }
  }

  Widget _buildImageWidget(String imagePath) {
    ImageProvider imageProvider;
    if (imagePath.startsWith('http')) {
      imageProvider = NetworkImage(imagePath);
    } else {
      imageProvider = FileImage(File(imagePath));
    }
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
    );
  }

  // payload 생성 후 PlaceInPage로 이동 (DB 저장은 PlaceInPage에서 "등록" 버튼으로 수행)
  void _goToPlaceInPage() {
    Map<String, dynamic> operatingHours = {};
    selectedDays.forEach((day, isOpen) {
      if (isOpen) {
        String start =
            "${startHour[day]!.toString().padLeft(2, '0')}:${startMinute[day]!.toString().padLeft(2, '0')}";
        String end =
            "${endHour[day]!.toString().padLeft(2, '0')}:${endMinute[day]!.toString().padLeft(2, '0')}";
        operatingHours[day] = {"start": start, "end": end};
      } else {
        operatingHours[day] = "휴무";
      }
    });
    List<Map<String, String>>? priceInfo =
        widget.priceList.isEmpty ? null : widget.priceList;

    Map<String, dynamic> payload = {
      "user_id": 1, // 실제 사용자 id로 대체
      "place_name": widget.placeData['place_name'],
      "description": descriptionController.text,
      "address": widget.placeData['address'],
      "phone": phoneController.text,
      "main_category": widget.placeData['main_category'] ?? "메인카테고리",
      "sub_category": widget.placeData['sub_category'] ?? "세부카테고리",
      "hashtags": hashtags,
      "images": imageList,
      "operating_hours": operatingHours,
      "price_info": priceInfo,
      ...widget.placeData,
    };

    Navigator.pushReplacementNamed(context, '/placeinpage', arguments: payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("장소 정보 입력", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFB9FDF9),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              "'${widget.placeData['place_name']}'의 추가 정보를 입력해주세요",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // 이미지 섹션
            Wrap(
              spacing: 10,
              children: [
                ...imageList.map((image) => _buildImageWidget(image)),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Icon(Icons.add, size: 30)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 장소 소개글 입력
            const Text("장소 소개글", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "장소를 소개해주세요.",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 장소 전화번호 입력
            const Text("장소 전화번호", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "전화번호 입력",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 해시태그 입력 및 추가
            const Text("해시태그", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hashtagController,
                    decoration: InputDecoration(
                      hintText: "해시태그 입력",
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addHashtag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: hashtags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            const SizedBox(height: 20),
            // 영업시간 설정 (요일별)
            const Text("영업시간", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Column(
              children: selectedDays.entries.map((entry) {
                final day = entry.key;
                final isSelected = entry.value;
                return Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleDaySelection(day),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.cyan : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.black),
                            ),
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: isSelected
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showSpinnerTimePicker(
                                            context, day, true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "${startHour[day]!.toString().padLeft(2, '0')}:${startMinute[day]!.toString().padLeft(2, '0')}",
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text("~",
                                          style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 5),
                                      GestureDetector(
                                        onTap: () => _showSpinnerTimePicker(
                                            context, day, false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "${endHour[day]!.toString().padLeft(2, '0')}:${endMinute[day]!.toString().padLeft(2, '0')}",
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text("휴무"),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // "다음 단계로" 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[100],
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _goToPlaceInPage,
              child: const Text("다음 단계로",
                  style: TextStyle(color: Colors.black, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
