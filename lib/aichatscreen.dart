import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'theme_colors.dart';

import 'aichat.dart'; // ChatMessage 모델
import 'openai_service.dart'; // OpenAIService
import 'constants.dart'; // BASE_URL 등

enum FlowType { none, place, course }

enum StepState {
  chooseFlow, // 장소 vs 코스
  askRegion, // 지역 입력
  askDistrict, // 구/군 선택
  askNeighborhood, // 동/읍/면 선택
  askQuery, // 누구와 무엇을
  askCourse, // 코스 내용 입력

  inChat
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = [];
  TextEditingController _chatController = TextEditingController();
  bool _isWaitingForAI = false;
  late OpenAIService _openAI;

  // 상태
  FlowType _flow = FlowType.none;
  StepState _step = StepState.chooseFlow;

  Map<String, dynamic> regionData = {};
  String? _region;
  String? _district;
  String? _neighborhood;
  String? _userQuery;
  String? _courseQuery;
  List<dynamic>? _coursePlaces;
  bool _awaitingCourseFeedback = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/regions.json').then((str) {
      setState(() => regionData = json.decode(str));
    });
    final apiKey = dotenv.env['OPENAI_API_KEY']!;
    _openAI = OpenAIService(apiKey);

    _sendAI('안녕하세요! 원하시는 장소 또는 코스를 추천해드립니다.\n어떤 서비스를 이용하시겠어요?');
  }

  void _addUser(String txt) {
    setState(() => _messages.add(ChatMessage(text: txt, fromAI: false)));
  }

  void _addAI(String txt) {
    setState(() => _messages.add(ChatMessage(text: txt, fromAI: true)));
  }

  Future<void> _sendAI(String prompt) async {
    _addAI(prompt);
  }

  // 버튼 제안
  List<String> get _suggestions {
    if (_awaitingCourseFeedback) {
      return ['예', '아니오'];
    }
    switch (_step) {
      case StepState.chooseFlow:
        return ['장소추천', '코스추천'];
      case StepState.askDistrict:
        final districts =
            regionData[_region]?.keys.cast<String>()?.toList() ?? [];
        return ['전체'] + districts;
      case StepState.askNeighborhood:
        final neighs =
            regionData[_region]?[_district]?.cast<String>()?.toList() ?? [];
        return ['전체'] + neighs;
      default:
        return [];
    }
  }

  // 버튼 눌렀을 때
  Future<void> _onTapSuggestion(String txt) async {
    _addUser(txt);
    if (_awaitingCourseFeedback) {
      _awaitingCourseFeedback = false;
      if (txt == '예') {
        await _saveCourse();
      } else {
        await _sendAI('알겠습니다.');
      }
      setState(() {});
      return;
    }
    switch (_step) {
      case StepState.chooseFlow:
        if (txt == '장소추천') {
          _flow = FlowType.place;
          _step = StepState.askRegion;
          await _sendAI('좋습니다! 어느 지역을 원하시나요? (예: 서울, 인천)');
        } else {
          _flow = FlowType.course;
          _step = StepState.askRegion;
          await _sendAI('좋습니다! 어느 지역을 원하시나요? (예: 서울, 인천)');
        }
        break;
      case StepState.askDistrict:
        if (txt == '전체') {
          _district = null;
          _step = StepState.askNeighborhood;
          await _sendAI('동/읍/면을 선택해주세요. (전체 가능)');
        } else {
          _district = txt;
          _step = StepState.askNeighborhood;
          await _sendAI('$txt의 동/읍/면을 선택해주세요.');
        }
        break;
      case StepState.askNeighborhood:
        if (txt == '전체') {
          _neighborhood = null;
        } else {
          _neighborhood = txt;
        }
        if (_flow == FlowType.course) {
          _step = StepState.askCourse;
          await _sendAI('원하시는 코스를 말해주세요.');
        } else {
          _step = StepState.askQuery;
          await _sendAI('누구와 무엇을 하고 싶으신가요? 예: 혼자 카페를 가고싶어.');
        }
        break;
      default:
        break;
    }
    setState(() {});
  }

  Future<void> _recommendPlace() async {
    await _sendAI('장소를 추천중입니다…');

    final fullRegion = [_region, _district, _neighborhood]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    try {
      final resp = await http.post(
        Uri.parse('$BASE_URL/aicourse/aiplace'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'region': fullRegion, 'userQuery': _userQuery ?? ''}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['places'] != null && (data['places'] as List).isNotEmpty) {
          for (var p in data['places']) {
            _addAI(
                '${p['place_name']} (${p['rating_avg'] ?? 'N/A'}⭐) ${p['address']}');
          }
        } else {
          _addAI(data['message'] ?? '죄송해요, 추천 장소를 찾지 못했습니다.');
        }
      } else {
        _addAI('서버 오류: 장소 추천 실패 (${resp.statusCode})');
      }
    } catch (e) {
      _addAI('죄송해요, 장소 추천 요청 중 오류가 발생했어요.');
    }
  }

  Future<void> _recommendCourse() async {
    await _sendAI('코스를 추천중입니다…');
    try {
      final resp = await http.get(
        Uri.parse('$BASE_URL/aicourse/fixed'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['course'] != null && data['course'] is List) {
          _coursePlaces = List<dynamic>.from(data['course']);
          int idx = 1;
          for (var p in _coursePlaces!) {
            _addAI('$idx. ${p['place_name']} - ${p['place_address']}');
            idx++;
          }
          await _sendAI('마음에 드십니까? (예/아니오)');
          _awaitingCourseFeedback = true;
        } else {
          _addAI('죄송해요, 추천 코스를 찾지 못했습니다.');
        }
      } else {
        _addAI('서버 오류: 코스 추천 실패 (${resp.statusCode})');
      }
    } catch (e) {
      _addAI('죄송해요, 코스 추천 요청 중 오류가 발생했어요.');
    }
  }

  Future<void> _saveCourse() async {
    if (_coursePlaces == null) return;
    final payload = {
      'user_id': 1,
      'course_name': _courseQuery ?? 'AI 추천 코스',
      'with_who': [],
      'purpose': [],
      'schedules': _coursePlaces,
    };
    try {
      final resp = await http.post(
        Uri.parse('$BASE_URL/aicourse/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 201) {
        await _sendAI('코스가 저장되었습니다.');
      } else {
        await _sendAI('코스 저장 실패 (${resp.statusCode})');
      }
    } catch (e) {
      await _sendAI('죄송해요, 코스 저장 중 오류가 발생했어요.');
    }
  }

  // 자유 입력 핸들러
  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isWaitingForAI) return;
    _addUser(text);
    _chatController.clear();

    if (_step == StepState.askRegion) {
      // ex: 서울 → 서울특별시 매칭
      String? matchedKey;
      for (var key in regionData.keys) {
        if (key.startsWith(text)) {
          matchedKey = key;
          break;
        }
      }
      if (matchedKey != null) {
        _region = matchedKey;
        _step = StepState.askDistrict;
        await _sendAI('$matchedKey의 구/군을 선택해주세요.');
      } else {
        await _sendAI('죄송해요, "$text" 지역을 찾지 못했어요. 다시 입력해주세요.');
      }
      setState(() {});
      return;
    }

    // 마지막 자유질문 (누구와 무엇을~)
    if (_step == StepState.askQuery) {
      _userQuery = text;
      _step = StepState.inChat;
      setState(() {});
      await _recommendPlace();
      return;
    }
    if (_step == StepState.askCourse) {
      _courseQuery = text;
      _step = StepState.inChat;
      setState(() {});
      await _recommendCourse();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 챗봇')),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: _messages.length,
          itemBuilder: (c, i) {
            final m = _messages[i];
            return Align(
              alignment:
                  m.fromAI ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color:
                          m.fromAI ? Colors.grey[200] : AppColors.accentLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(m.text)),
            );
          },
        )),
        if (_suggestions.isNotEmpty)
          SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => SizedBox(width: 8),
                itemBuilder: (_, i) => ElevatedButton(
                    onPressed: () => _onTapSuggestion(_suggestions[i]),
                    child: Text(_suggestions[i])),
              )),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(hintText: '메시지를 입력하세요'),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: _isWaitingForAI
                    ? CircularProgressIndicator()
                    : Icon(Icons.send),
                onPressed: _sendMessage,
              )
            ]))
      ]),
    );
  }
}
