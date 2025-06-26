import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'constants.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({Key? key}) : super(key: key);

  // 메뉴 아이템 목록
  static const List<_AdminMenuItem> _menus = [
    //_AdminMenuItem(title: "유저 관리", routeName: "/admin/users"),
    _AdminMenuItem(title: "게시글 신고 관리", routeName: "/admin/post-reports"),
    _AdminMenuItem(title: "장소 승인 요청", routeName: "/admin/place-requests"),
    _AdminMenuItem(title: "장소 신고 관리", routeName: "/admin/place-reports"),
    _AdminMenuItem(title: "문의 관리", routeName: "/admin/inquiries"),
    _AdminMenuItem(title: "포인트 상점 관리", routeName: "/admin/shop"),
  ];

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<UserProvider>().isAdmin;
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('관리자 전용 페이지입니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("관리자 대시보드"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              Provider.of<UserProvider>(context, listen: false).clearUserData();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
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
              print('▶ 장소 승인 요청 이동 시도');

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
