import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home.dart';
import 'login.dart';
import 'signup.dart';
import 'my.dart';
import 'food.dart';
import 'board.dart';
import 'user_provider.dart';
import 'write_post.dart';
import 'post.dart';
import 'place.dart';
import 'placeadd.dart';
import 'price.dart';
import 'placein.dart';
import 'category.dart';
import 'navermap.dart';
import 'foodplace.dart';
import 'cafe.dart';
import 'play.dart';
import 'see.dart';
import 'walk.dart';
import 'zzim.dart';
import 'zzimdetail.dart';
import 'course.dart';
import 'course2.dart';
import 'course3.dart';
import 'zzimlist.dart';
import 'selectplace.dart';
import 'allplace.dart';
import 'review_provider.dart';
import 'fri.dart';
import 'AICourse.dart';
import 'AIcourse2.dart';
import 'all_courses_page.dart';
import 'adminpage.dart';
import 'aichatscreen.dart';
import 'admin_place_requests_page.dart';
import 'admin_place_reports_page.dart';
import 'admin_inquiry_list_page.dart';
import 'inquiry_page.dart';
import 'course_detail_loader.dart';
import 'admin_edit_place_page.dart';
import 'admin_post_reports_page.dart';
import 'admin_shop_page.dart';
import 'public_collections_page.dart';
import 'theme_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    await dotenv.load(fileName: "assets/.env");
    print("✅ .env 파일 로드 완료");
  } catch (e) {
    print("❌ .env 파일 로드 오류: $e");
  }
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '', // 또는 직접 입력
    onAuthFailed: (error) {
      print('네이버 지도 인증 실패: $error');
    },
  );
  KakaoSdk.init(nativeAppKey: "2335e028a51784148baef28bac903d8c");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()), // 추가
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Date App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBar,
          elevation: 0,
          shape: Border(
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentLight,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/signup': (context) => const SignupPage(),
        '/my': (context) => const MyPage(),
        '/food': (context) => const FoodPage(),
        '/cafe': (context) => const CafePage(),
        '/see': (context) => const SeePage(),
        '/walk': (context) => const WalkPage(),
        '/play': (context) => const PlayPage(),
        '/board': (context) => const BoardPage(),
        '/writePost': (context) => const WritePostPage(),
        '/place': (context) => const PlacePage(),
        '/navermap': (context) => const NaverMapScreen(),
        '/zzim': (context) => const ZzimPage(),
        '/course': (context) => const CourseCreationPage(),
        '/all': (context) => const AllplacePage(),
        '/fri': (context) => const FriPage(),
        '/AICourse': (context) => const AICoursePage(),
        '/allcourse': (context) => const AllCoursesPage(),
        '/admin': (context) => const AdminPage(),
        '/aichat': (context) => const ChatScreen(),
        '/admin/place-requests': (context) => const AdminPlaceRequestsPage(),
        '/admin/place-reports': (context) => const AdminPlaceReportsPage(),
        '/admin/inquiries': (context) => const AdminInquiryListPage(),
        '/admin/post-reports': (context) => const AdminPostReportsPage(),
        '/admin/shop': (context) => const AdminShopPage(),
        '/publicCollections': (context) => const PublicCollectionsPage(),

        //'/admin/inquiries': (context) => const AdminInquiryListPage(),
        '/admin/edit-place': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return AdminEditPlaceFormPage(
            placeId: args['placeId'] as int,
            reportId: args['reportId'] as int,
            reason: args['reason'] as String?,
            category: args['category'] as String?,
          );
        },
        '/inquiry': (context) => const InquiryPage(),
        '/CategorySelectionPage': (context) =>
            const CategorySelectionPage(), // Add this line
      },
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == '/zzimlist') {
          // settings.arguments로 userId를 전달받는 방식
          final int userId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => ZzimListDialog(userId: userId),
          );
        }
        if (settings.name == '/zzimdetail') {
          final collection = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CollectionDetailPage(collection: collection),
          );
        }
        if (settings.name == '/selectplace') {
          final collection = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CollectionDetailPage(collection: collection),
          );
        }
        if (settings.name == '/post') {
          final args = settings.arguments;
          if (args is int) {
            return MaterialPageRoute(
              builder: (context) => PostPage(postId: args),
            );
          } else if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              builder: (context) => PostPage(
                postId: args['postId'] as int,
                reportId: args['reportId'] as int?,
              ),
            );
          }
        } else if (settings.name == '/price') {
          final Map<String, dynamic> args =
              settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PriceInfoPage(placeData: args),
          );
        } else if (settings.name == '/placeadd') {
          final Map<String, dynamic> args =
              settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PlaceAdditionalInfoPage(
              placeData: args,
              priceList: [], // PriceInfoPage에서 입력한 가격 정보가 없으면 빈 리스트로 전달
            ),
          );
        } else if (settings.name == '/placeinpage') {
          final Map<String, dynamic> payload =
              settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PlaceInPage(payload: payload),
          );
        }

        return null;
      },
    );
  }
}
