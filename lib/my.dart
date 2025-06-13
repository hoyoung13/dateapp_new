import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'profile.dart';
import 'couple.dart';
import 'place.dart';
import 'dart:io';
import 'fri.dart';
import 'inquiry_page.dart';
import 'point_history_page.dart';
import 'purchase_history_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final int _selectedIndex = 4; // ✅ MY 페이지에서 시작

  final List<Widget> _pages = [
    const Center(child: Text('🏠 HOME 화면')),
    const Center(child: Text('💬 커뮤니티 화면')),
    const Center(child: Text('❤️ 찜 목록 화면')),
    const Center(child: Text('🎉 EVENT 화면')),
    const MyPage(),
  ];

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // 같은 탭이면 리로드 방지

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home', // ✅ 등록된 라우트 이름 사용 (HomePage)
      (route) => false, // 모든 기존 페이지를 제거하고 새 페이지를 로드
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final String nickname = userProvider.nickname ?? "사용자 닉네임";
    final String? profileImagePath = userProvider.profileImagePath;

    return Scaffold(
      body: Column(
        children: [
          // ✅ 상단 Cyan 배경 적용
          Container(
            color: Colors.cyan[100],
            padding: const EdgeInsets.only(top: 50, bottom: 20), // 상단 간격 추가
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    "마이페이지",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.black),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // ✅ 프로필 섹션
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Colors.white,
            child: Row(
              children: [
                // 원형 프로필 이미지
                CircleAvatar(
                  radius: 40,
                  backgroundImage: userProvider.profileImagePath != null &&
                          userProvider.profileImagePath!.isNotEmpty
                      ? NetworkImage(userProvider.profileImagePath!)
                          as ImageProvider
                      : AssetImage('assets/profile.png'), // 기본 이미지
                ),
                const SizedBox(width: 15),
                // 이름 + 내 정보 수정, 로그아웃
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const EditProfilePage()),
                            ).then((_) {
                              setState(() {}); // ✅ 프로필 수정 후 UI 업데이트
                            });
                          },
                          child: const Text("내 정보 수정",
                              style: TextStyle(color: Colors.pink)),
                        ),
                        Text("|", style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: () {
                            Provider.of<UserProvider>(context, listen: false)
                                .clearUserData();
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text("로그아웃",
                              style: TextStyle(color: Colors.pink)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ✅ 포인트 섹션
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("포인트",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  "${userProvider.points} P",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink),
                ),
              ],
            ),
          ),
          const Divider(),

          // ✅ 리스트 섹션
          Expanded(
            child: ListView(
              children: [
                _buildListTile("커플 관리", Icons.coffee, isNew: true, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CouplePage()),
                  );
                }),
                _buildListTile("장소 제안", Icons.shopping_bag, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PlacePage()), // ✅ 이동
                  );
                }),
                _buildListTile(
                  "포인트 내역",
                  Icons.favorite,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PointHistoryPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  "포인트 구매 목록",
                  Icons.shopping_cart,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PurchaseHistoryPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  "친구 관리",
                  Icons.history,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FriPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  "문의 하기",
                  Icons.history,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InquiryPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      // ✅ 하단 네비게이션 바 유지!
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '찜 목록'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'EVENT'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'MY'),
        ],
      ),
    );
  }

  // ✅ 리스트 아이템 생성 함수
  Widget _buildListTile(String title, IconData icon,
      {bool isNew = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: isNew
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("NEW!",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                Icon(Icons.chevron_right),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap ?? () {},
    );
  }
}
