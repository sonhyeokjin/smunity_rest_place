import 'package:flutter/material.dart';
import 'package:smunity_rest_place/screens/login_screen.dart';
import 'package:smunity_rest_place/screens/signup_screen.dart';

class LoginPage extends StatelessWidget {
  final Color smBlue = const Color(0xFF0E207F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_background.png',
              fit: BoxFit.cover, // 화면 전체를 덮도록 설정
              errorBuilder: (context, error, stackTrace) {
                print("Error loading background image: $error");
                return Container(color: smBlue);
              },
            ),
          ),

          // 2. 반투명 오버레이 (텍스트/버튼 가독성 향상용)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),

          // 3. 실제 콘텐츠 (SafeArea 적용)
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // 요소들을 중앙 정렬
                  children: [
                    // 상단 공간 확보
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    // 상단 텍스트 영역
                    Column(
                      children: [
                        Text(
                          'SMunity',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cooper Black', // Cooper Black 폰트
                            fontSize: 42,
                            // 배경 오버레이가 어두우므로 흰색 텍스트 사용
                            color: Colors.white,
                            letterSpacing: 2.5,
                            shadows: [ // 텍스트 가독성을 위한 그림자
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black.withOpacity(0.5), // 그림자 농도 조절
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '상명대학교 캠퍼스 휴식 공간',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9), // 밝은 색상
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            shadows: [ // 작은 글씨에도 그림자 추가
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.black.withOpacity(0.4),
                                offset: Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 텍스트와 버튼 사이 공간 확보
                    Spacer(),
                    // 하단 버튼 영역
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavigateButton(
                          context: context,
                          text: '로그인',
                          // 흰색 배경, SM Blue 텍스트 (배경과 대비)
                          backgroundColor: Colors.white,
                          textColor: smBlue,
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LoginScreen()));
                          },
                        ),
                        SizedBox(height: 18),
                        _buildNavigateButton(
                          context: context,
                          text: '회원가입',
                          // 밝은 회색 배경, 어두운 텍스트 (로그인 버튼과 구분)
                          backgroundColor: Colors.white.withOpacity(0.9),
                          textColor: Colors.black87,
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => SignupScreen()));
                          },
                        ),
                      ],
                    ),
                    // 하단 공간 확보
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 버튼 생성을 위한 헬퍼 위젯
  Widget _buildNavigateButton({
    required BuildContext context,
    required String text,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        minimumSize: Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderColor != null
              ? BorderSide(color: borderColor, width: 1.5)
              : BorderSide.none,
        ),
        elevation: backgroundColor == Colors.transparent ? 0 : 2,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}