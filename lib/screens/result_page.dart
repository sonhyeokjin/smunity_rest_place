import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'emotion_chart_page.dart';

class ResultPage extends StatefulWidget {
  final User user;
  final List<Map<String, dynamic>> recommendations;
  final bool isHealingResult;

  const ResultPage({
    super.key,
    required this.user,
    required this.recommendations,
    this.isHealingResult = false,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  int _selectedIndex = 0; // 하단 네비게이션 바의 초기 선택 인덱스

  // 앱 PrimaryColor
  final Color smBlue = const Color(0xFF002D72); // 상명대학교 주요 색상
  final Color scaffoldBgColor = const Color(0xFFF0F4FA); // 페이지 배경색
  final Color cardColor = Colors.white; // 카드 배경색

  // 하단 네비게이션 탭 선택 시 호출되는 함수
  void _onItemTapped(int index) {
    if (_selectedIndex == index && index != 1) return;

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EmotionChartPage(user: widget.user)),
      ).then((_) {
        if (mounted && _selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    } else if (index == 2) { // 로그아웃 처리
      FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    } else {
      if (mounted) { // mounted 확인 후 setState 호출
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  // 공간 이미지를 보여주는 다이얼로그 함수
  void _showImageDialog(BuildContext context, String imageUrl, String spaceName) {
    debugPrint('이미지 로드 시도 URL: $imageUrl'); // 디버깅용 로그
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(spaceName, style: TextStyle(color: smBlue, fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.all(8.0),
          content: InteractiveViewer( // 이미지 확대/축소 지원
            panEnabled: false,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  heightFactor: 2,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(smBlue),
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                return Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 8),
                      Text('이미지를 불러올 수 없습니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                    ],
                  ),
                );
              },
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: smBlue),
              child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    );
  }

  // 추천 이유를 보여주는 새로운 다이얼로그 함수
  void _showReasonDialog(BuildContext context, String? reason, String spaceName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(spaceName, style: TextStyle(color: smBlue, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Text(
              reason ?? '추천 이유를 불러올 수 없습니다.', // reason이 null일 경우 기본 메시지
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: smBlue),
              child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    );
  }

  // 추천 카드 내의 상세 정보 행을 만드는 Helper Widget
  Widget _buildRecommendationDetailRow({required IconData icon, required String text, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 아이콘과 텍스트 상단 정렬
        children: [
          Icon(icon, color: iconColor ?? Colors.grey[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.grey[800]),
              maxLines: 3, // 여러 줄 표시 가능하도록 maxLines 설정
              overflow: TextOverflow.ellipsis, // 내용이 넘칠 경우 '...' 처리
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        // isHealingResult 값에 따라 AppBar 제목 변경
        title: Text(
            widget.isHealingResult ? '특별 힐링 추천 공간' : '추천 휴식 공간',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: smBlue, // State 클래스에 smBlue 변수가 정의되어 있다고 가정
        elevation: 2.0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: widget.recommendations.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sentiment_dissatisfied_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                '추천할 장소가 없어요.\n다른 감정으로 다시 시도해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[600], height: 1.5),
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12.0), // 리스트 전체 패딩
        itemCount: widget.recommendations.length,
        itemBuilder: (context, index) {
          final recommendation = widget.recommendations[index];
          // Null-safe하게 데이터 추출 및 기본값 설정
          final String spaceName = recommendation['space_name'] as String? ?? '이름 없음';
          final double score = (recommendation['score'] as num?)?.toDouble() ?? 0.0;
          final String tags = recommendation['tags'] as String? ?? '태그 없음';
          final String? imageUrl = recommendation['image_url'] as String?;
          final String? description = recommendation['description'] as String?;
          final String? reason = recommendation['reason'] as String?;

          bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
          bool hasReason = reason != null && reason.isNotEmpty && reason != "추천 이유를 생성하는 데 필요한 설정을 확인해주세요." && reason != "추천 이유를 생성하는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요." && reason != "이 공간은 현재 고객님의 감정에 잘 맞을 것으로 예상됩니다.";


          return Card(
            color: cardColor,
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // 카드 간 간격
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spaceName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: smBlue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRecommendationDetailRow(
                    icon: Icons.star_outline,
                    text: '추천 점수: ${score.toStringAsFixed(1)}점',
                    iconColor: Colors.amber[700],
                  ),
                  const SizedBox(height: 4),
                  _buildRecommendationDetailRow(
                    icon: Icons.local_offer_outlined,
                    text: '관련 태그: $tags',
                    iconColor: Colors.green[700],
                  ),
                  if (description != null && description.isNotEmpty && description != '설명 없음') ...[
                    const SizedBox(height: 4),
                    _buildRecommendationDetailRow(
                      icon: Icons.info_outline,
                      text: '공간 설명: $description',
                      iconColor: Colors.blueGrey[700],
                    ),
                  ],
                  const SizedBox(height: 16), // 버튼 영역 상단 여백
                  // 이미지 보기 및 추천 이유 보기 버튼 Row
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.image_outlined, size: 18),
                          label: const Text('이미지 보기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: smBlue.withOpacity(0.12),
                            foregroundColor: smBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                side: BorderSide(color: smBlue.withOpacity(0.3))
                            ),
                          ),
                          onPressed: hasImage
                              ? () => _showImageDialog(context, imageUrl, spaceName)
                              : null, // 이미지 없으면 비활성화
                        ),
                      ),
                      const SizedBox(width: 10), // 버튼 사이 간격
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.lightbulb_outline, size: 18),
                          label: const Text('추천 이유'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: smBlue.withOpacity(0.12),
                            foregroundColor: smBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                side: BorderSide(color: smBlue.withOpacity(0.3))
                            ),
                          ),
                          onPressed: hasReason
                              ? () => _showReasonDialog(context, reason, spaceName)
                              : null, // 추천 이유 없으면 비활성화
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: cardColor,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: smBlue,
        unselectedItemColor: Colors.grey[600],
        elevation: 10.0,
        type: BottomNavigationBarType.fixed, // 아이템이 3개 이상일 때 고정된 스타일
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt_rounded), // 선택 시 아이콘
            label: '추천 목록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: '감정 그래프',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout_outlined),
            activeIcon: Icon(Icons.logout),
            label: '로그아웃',
          ),
        ],
      ),
    );
  }
}