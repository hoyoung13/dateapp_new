import 'package:flutter/material.dart';

class CategorySelectionPage extends StatefulWidget {
  const CategorySelectionPage({super.key});

  @override
  State<CategorySelectionPage> createState() => _CategorySelectionPageState();
}

class Category {
  final String label;
  final IconData icon;
  const Category(this.label, this.icon);
}

const List<Category> mainCategories = [
  Category('먹기', Icons.restaurant),
  Category('마시기', Icons.local_cafe),
  Category('놀기', Icons.sports_esports),
  Category('보기', Icons.movie),
  Category('걷기', Icons.directions_walk),
];
const Map<String, List<String>> subCategories = {
  '먹기': ['밥', '고기', '면', '해산물', '길거리', '샐러드', '빵'],
  '마시기': ['커피', '차/음료', '디저트', '맥주', '소주', '막걸리', '칵테일/와인'],
  '놀기': ['실외활동', '실내활동', '게임/오락', '힐링', 'VR/방탈출', '만들기'],
  '보기': ['영화', '전시', '공연', '박물관', '스포츠', '쇼핑'],
  '걷기': ['시장', '공원', '테마거리', '야경/풍경', '문화제'],
};

class _CategorySelectionPageState extends State<CategorySelectionPage> {
  // 메인 카테고리 목록 (아이콘 + 라벨)
  final List<Map<String, dynamic>> mainCategories = [
    {"label": "먹기", "icon": Icons.restaurant},
    {"label": "마시기", "icon": Icons.local_cafe},
    {"label": "놀기", "icon": Icons.sports_esports},
    {"label": "보기", "icon": Icons.movie},
    {"label": "걷기", "icon": Icons.directions_walk},
  ];

  // 세부 카테고리 목록 (메인 카테고리 → 서브 카테고리들)
  final Map<String, List<String>> subCategories = {
    "먹기": ["밥", "고기", "면", "해산물", "길거리", "샐러드", "빵"],
    "마시기": ["커피", "차/음료", "디저트", "맥주", "소주", "막걸리", "칵테일/와인"],
    "놀기": ["실외활동", "실내활동", "게임/오락", "힐링", "VR/방탈출", "만들기"],
    "보기": ["영화", "전시", "공연", "박물관", "스포츠", "쇼핑"],
    "걷기": ["시장", "공원", "테마거리", "야경/풍경", "문화제"],
  };

  // 선택된 메인/서브 카테고리
  String? selectedMainCategory;
  String? selectedSubCategory;
  final List<String> selectedWithWho = [];
  final List<String> selectedPurpose = [];
  final List<String> selectedMood = [];

  // 옵션 리스트 정의
  static const List<String> withWhoOptions = ['혼자', '친구', '연인', '가족', '반려동물'];
  static const List<String> purposeOptions = ['식사', '데이트', '힐링', '운동', '회식'];
  static const List<String> moodOptions = ['로맨틱', '액티브', '편안함', '모던', '전통적'];

  @override
  Widget build(BuildContext context) {
    // 이전 화면에서 전달받은 payload
    final Map<String, dynamic>? prevPayload =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // 메인 카테고리 선택 시, 해당하는 서브 카테고리 목록 가져오기
    final List<String> currentSubList = selectedMainCategory != null
        ? subCategories[selectedMainCategory!]!
        : [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB9FDF9),
        title: const Text("카테고리 선택", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        // ➞ 전체 스크롤 가능하도록 감싸기
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "부천대학교의 카테고리를 선택해주세요.\n(1/2)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "카테고리",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: mainCategories.map((cat) {
                  final label = cat["label"] as String;
                  final iconData = cat["icon"] as IconData;
                  final isSelected = (label == selectedMainCategory);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedMainCategory = label;
                        selectedSubCategory = null;
                      });
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color.fromARGB(255, 170, 238, 247)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData,
                              color: isSelected ? Colors.white : Colors.black),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                "세부 카테고리",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              if (selectedMainCategory == null)
                const Text(
                  "메인 카테고리를 먼저 선택해주세요.",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: currentSubList.map((sub) {
                    final isSubSelected = (sub == selectedSubCategory);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedSubCategory = sub;
                        });
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: isSubSelected
                              ? const Color.fromARGB(255, 153, 239, 250)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            sub,
                            style: TextStyle(
                              color:
                                  isSubSelected ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              const Text("누구와 함께?",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: withWhoOptions.map((o) {
                  final sel = selectedWithWho.contains(o);
                  return _buildSelectableBox(
                    label: o,
                    selected: sel,
                    onTap: () {
                      setState(() {
                        if (sel)
                          selectedWithWho.remove(o);
                        else
                          selectedWithWho.add(o);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text("목적", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: purposeOptions.map((o) {
                  final sel = selectedPurpose.contains(o);
                  return _buildSelectableBox(
                    label: o,
                    selected: sel,
                    onTap: () {
                      setState(() {
                        if (sel)
                          selectedPurpose.remove(o);
                        else
                          selectedPurpose.add(o);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text("분위기", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: moodOptions.map((o) {
                  final sel = selectedMood.contains(o);
                  return _buildSelectableBox(
                    label: o,
                    selected: sel,
                    onTap: () {
                      setState(() {
                        if (sel)
                          selectedMood.remove(o);
                        else
                          selectedMood.add(o);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedMainCategory == null ||
                        selectedSubCategory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("메인/세부 카테고리를 모두 선택해주세요.")),
                      );
                      return;
                    }
                    final Map<String, dynamic> payload = {
                      'place_name': prevPayload?['place_name'] ?? '장소 이름',
                      'address': prevPayload?['address'] ?? '주소 없음',
                      'main_category': selectedMainCategory,
                      'sub_category': selectedSubCategory,
                      'with_who': selectedWithWho,
                      'purpose': selectedPurpose,
                      'mood': selectedMood,
                    };

                    Navigator.pushNamed(context, '/price', arguments: payload);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB9FDF9),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    "다음 단계로",
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableBox({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF99EFFA) : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
