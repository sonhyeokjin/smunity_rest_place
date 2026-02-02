import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'login_page.dart';
import 'recommend_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Animation Controller
  late final AnimationController _lottieController;
  late final AnimationController _titleTextController;
  late final Animation<double> _titleFadeAnimation;
  late final Animation<Offset> _titleSlideAnimation;
  late final AnimationController _copyrightTextController;
  late final Animation<double> _copyrightFadeAnimation;
  late final Animation<Offset> _copyrightSlideAnimation;

  // File Path
  final String _lottieAssetPath = 'assets/lottie/sm_abstract_splash.json';
  // 스플래시 화면 최소 표시 시간
  final Duration _minSplashDuration = const Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    // Lottie 컨트롤러 초기화
    _lottieController = AnimationController(vsync: this);

    // 텍스트 애니메이션 컨트롤러 초기화
    _titleTextController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _copyrightTextController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // 텍스트 애니메이션 정의
    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleTextController, curve: Curves.easeOut),
    );
    _titleSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _titleTextController, curve: Curves.easeOutCubic),
    );
    _copyrightFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _copyrightTextController, curve: Curves.easeOut),
    );
    _copyrightSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _copyrightTextController, curve: Curves.easeOutCubic),
    );

    // Lottie 애니메이션 로드가 완료되면 _onLottieLoaded 콜백이 호출됨
    // 거기서 애니메이션 시작 및 화면 전환 로직 실행
  }

  // Lottie 애니메이션 로드 완료 시 호출
  void _onLottieLoaded(LottieComposition composition) {
    // Lottie 애니메이션 재생 시간 설정 및 재생
    _lottieController.duration = composition.duration;

    final stopwatch = Stopwatch()..start(); // Start StopWatch

    _lottieController.forward().whenComplete(() {
      // Lottie 애니메이션 재생 완료 후
      final elapsed = stopwatch.elapsed; // 경과 시간 측정
      final remainingTime = _minSplashDuration - elapsed;

      if (remainingTime > Duration.zero) {
        // 최소 표시 시간보다 Lottie 애니메이션이 빨리 끝났다면, 남은 시간만큼 추가 대기
        Future.delayed(remainingTime, _navigateToNextScreen);
      } else {
        // 최소 표시 시간을 이미 채웠거나 넘겼다면 바로 화면 전환
        _navigateToNextScreen();
      }
    });

    // 텍스트 애니메이션들 시작
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _titleTextController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _copyrightTextController.forward();
    });
  }

  // 로그인 상태 확인 후 적절한 다음 화면으로 이동하는 함수
  void _navigateToNextScreen() {
    // 위젯이 여전히 화면에 마운트된 상태인지 확인
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser; // 현재 로그인된 사용자 확인

    Widget nextPage;
    if (user != null) {
      // 로그인된 사용자가 있으면 RecommendPage로 이동
      // RecommendPage는 User 객체를 필요로 함
      nextPage = RecommendPage(user: user);
    } else {
      // 로그인된 사용자가 없으면 LoginPage로 이동
      // LoginPage는 User 객체를 필요로 하지 않음
      nextPage = LoginPage();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  @override
  void dispose() {
    // 컨트롤러들을 반드시 dispose하여 메모리 누수 방지
    _lottieController.dispose();
    _titleTextController.dispose();
    _copyrightTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI 구성
    Color screenBackgroundColor = const Color(0xFF002D72);
    double lottieOverlayOpacity = 0.5; // Lottie 애니메이션 위에 덮을 검은색 오버레이의 투명도

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: Stack(
        alignment: Alignment.center, // 자식 위젯들을 중앙 정렬
        children: [
          Positioned.fill( // 화면 전체를 채우도록
            child: Lottie.asset(
              _lottieAssetPath,
              controller: _lottieController,
              onLoaded: _onLottieLoaded, // Lottie 로드 완료 시 콜백
              fit: BoxFit.cover, // Lottie 애니메이션이 화면을 덮도록 설정
              errorBuilder: (context, error, stackTrace) {
                // Lottie 로드 실패 시 처리
                debugPrint("Lottie Error: $error"); // 디버그 콘솔에 에러 출력
                // Lottie 로드 실패 시에도 최소 지연 시간 후 다음 화면으로 이동 시도
                Future.delayed(_minSplashDuration, _navigateToNextScreen);
                return const Center(
                  child: Text(
                    '앱을 시작하는 중입니다...',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                );
              },
            ),
          ),
          // Lottie 위에 반투명 검은색 오버레이 (텍스트 가독성 향상)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(lottieOverlayOpacity),
            ),
          ),
          // "SANGMYUNG REST PLACE" 텍스트 (애니메이션 적용)
          Positioned(
            // 화면 높이에 따라 동적으로 위치 조절 가능
            top: MediaQuery.of(context).size.height * 0.35,
            child: FadeTransition(
              opacity: _titleFadeAnimation,
              child: SlideTransition(
                position: _titleSlideAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SANGMYUNG',
                      style: TextStyle(
                        fontFamily: 'Cooper Black', // Cooper Black 폰트
                        fontSize: 38,
                        color: Colors.white,
                        letterSpacing: 3.5,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'REST PLACE',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w300,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black.withOpacity(0.4),
                            offset: const Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 하단 저작권 텍스트 (애니메이션 적용)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: FadeTransition(
                opacity: _copyrightFadeAnimation,
                child: SlideTransition(
                  position: _copyrightSlideAnimation,
                  child: Text(
                    '@Copyright SMunity', // 기존 텍스트 유지
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.75),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}