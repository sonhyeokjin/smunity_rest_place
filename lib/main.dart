import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:smunity_rest_place/screens/splash_screen.dart';
import 'firebase_options.dart';


final Color smuPrimaryColor = const Color(0xFF002D72);
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 앱 UI가 화면 가장자리까지 확장되도록 설정
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 시스템 UI 오버레이 스타일을 상세하게 설정하여 하단 바를 투명하게 설정
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    // 상태 표시줄을 투명하게 설정
    statusBarColor: Colors.transparent,
    // 앱의 전반적인 배경이 밝으므로 상태 표시줄 아이콘은 어둡게 설정
    statusBarIconBrightness: Brightness.dark,

    // 하단 시스템 Navigation Bar
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,

    // Android API 29 이상에서 시스템이 네비게이션 바에 강제로 보호색을 입히는 것을 방지
    systemNavigationBarContrastEnforced: false,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SANGMYUNG REST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Cooper Black',
        colorScheme: ColorScheme.fromSeed(seedColor: smuPrimaryColor),
        useMaterial3: true,

        appBarTheme: AppBarTheme(
          backgroundColor: smuPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0.5,
          // AppBar가 상태 표시줄 영역을 덮을 때, 상태 표시줄 아이콘/텍스트 색상을 밝게 설정
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Cooper Black',
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),

        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
          },
        ),

        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Cooper Black',
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: smuPrimaryColor,
          ),
          bodyMedium: const TextStyle(fontSize: 16, fontFamily: 'Pretendard'),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: smuPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
          ),
        ),
      ),
      home: SplashScreen(),
      navigatorObservers: [routeObserver],
    );
  }
}