import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({Key? key}) : super(key: key);

  // 메뉴 아이템 목록
  static const List<_AdminMenuItem> _menus = [
    _AdminMenuItem(title: "유저 관리", routeName: "/admin/users"),
    _AdminMenuItem(title: "게시글 관리", routeName: "/admin/posts"),
    _AdminMenuItem(title: "장소 관리", routeName: "/admin/places"),
    _AdminMenuItem(title: "문의 관리", routeName: "/admin/inquiries"),
    _AdminMenuItem(title: "코스 관리", routeName: "/admin/courses"),
    _AdminMenuItem(title: "찜 관리", routeName: "/admin/favorites"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("관리자 대시보드"),
        centerTitle: true,
      ),
      body: ListView.separated(
        itemCount: _menus.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final menu = _menus[index];
          return ListTile(
            title: Text(
              menu.title,
              style: const TextStyle(fontSize: 18),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 향후 각 관리 화면으로 연결될 라우트로 이동
              Navigator.pushNamed(context, menu.routeName);
            },
          );
        },
      ),
    );
  }
}

// 메뉴 아이템 타입 정의
class _AdminMenuItem {
  final String title;
  final String routeName;
  const _AdminMenuItem({
    required this.title,
    required this.routeName,
  });
}
