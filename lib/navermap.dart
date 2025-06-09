import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class NaverMapScreen extends StatefulWidget {
  const NaverMapScreen({Key? key}) : super(key: key);

  @override
  _NaverMapScreenState createState() => _NaverMapScreenState();
}

class _NaverMapScreenState extends State<NaverMapScreen> {
  // 초기 카메라 위치를 서울로 설정 (원하는 좌표로 수정 가능)
  final NCameraPosition _initialCameraPosition = NCameraPosition(
    target: NLatLng(37.5665, 126.9780), // 서울
    zoom: 15,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Naver Map Demo"),
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: _initialCameraPosition,
        ),
        onMapReady: (controller) {
          // 지도 로딩 후 실행할 추가 작업이 있다면 여기에 작성
        },
      ),
    );
  }
}
