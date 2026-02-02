import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import '../services/api_service.dart';
import 'result_page.dart';
import 'emotion_chart_page.dart';
import '../route_observer.dart';
import 'package:smunity_rest_place/screens/my_page.dart';

class RecommendPage extends StatefulWidget {
  final User user;
  const RecommendPage({super.key, required this.user});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

enum InputMode { emotion, purpose }

class _RecommendPageState extends State<RecommendPage> with RouteAware {

  // AppBar 텍스트 애니메이션
  late Timer _appBarTextTimer;
  int _currentAppBarTextIndex = 0;
  final List<String> _appBarTexts = [
    "SMU 공간 추천", // 기본 제목
    "오늘, 어떤 공간이 필요하세요?",
    "당신에게 맞는 휴식처를 찾아보세요.",
    "상명대 휴식공간, AI와 찾아보세요"
  ];

  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _emotionHistory = [];
  int _selectedIndex = 0;
  bool _isLoadingHistory = true;

  // 현재 입력 모드를 저장하는 상태 변수, 기본값은 감정 기반
  InputMode _currentInputMode = InputMode.emotion;

  final Color _sBlue = const Color(0xFF002D72);
  final Color _scaffoldBgColor = const Color(0xFFF0F4FA);
  final Color _cardColor = Colors.white;

  DateTime? _lastBackPressed;

  final Map<String, int> _emotionScoreMap = {
    '기쁨': 80, '행복': 90, '신남': 85, '평온': 70,
    '만족': 75, '슬픔': 30, '우울': 20, '불안': 35,
    '짜증': 40, '분노': 25, '피곤': 45, '혼란': 50,
    '무기력': 15,
  };

  final String _lastLowStreakAlertTimeKey = 'lastLowStreakAlertTimestamp';
  final Duration _lowStreakAlertCooldown = const Duration(hours: 24);
  final int _lowScoreThreshold = 30;
  final int _consecutiveLowScoreCount = 3;

  @override
  void initState() {
    super.initState();
    _fetchEmotionHistory();

    // AppBar 텍스트 변경 타이머
    _appBarTextTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) { // 위젯이 계속 화면에 있을 때만 상태 변경
        setState(() {
          _currentAppBarTextIndex = (_currentAppBarTextIndex + 1) % _appBarTexts.length;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    _appBarTextTimer.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext(); // super.didPopNext() 호출
    debugPrint("RecommendPage: didPopNext called!"); // 호출 여부 확인용 로그
    if (mounted) {
      setState(() {
        _selectedIndex = 0; // 홈 탭(인덱스 0)으로 강제 선택 상태
      });
    }
  }

  Future<void> _fetchEmotionHistory() async {
    if (!mounted) return;
    if (!_isLoadingHistory) {
      setState(() { _isLoadingHistory = true; });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('emotion_history')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _emotionHistory = snapshot.docs.map((doc) {
            var data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingHistory = false; });
      }
      debugPrint("Error fetching emotion history: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('감정 히스토리를 불러오는데 실패했습니다: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _checkAndNotifyLowStreak() async {
    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? lastAlertTimestampMillis = prefs.getInt(_lastLowStreakAlertTimeKey);

    if (lastAlertTimestampMillis != null) {
      final DateTime lastAlertTime = DateTime.fromMillisecondsSinceEpoch(lastAlertTimestampMillis);
      if (DateTime.now().difference(lastAlertTime) < _lowStreakAlertCooldown) {
        debugPrint("Low streak alert cooldown is active. Not showing alert. Last alert was at: $lastAlertTime");
        return;
      }
    }

    try {
      final historySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('emotion_history')
          .orderBy('timestamp', descending: true)
          .limit(_consecutiveLowScoreCount)
          .get();

      if (historySnapshot.docs.length < _consecutiveLowScoreCount) {
        debugPrint("Not enough records to check for low score streak.");
        return;
      }

      List<int> recentScores = historySnapshot.docs.map((doc) {
        return (doc.data()['numeric_score'] as num?)?.toInt() ?? 101;
      }).toList();

      bool streakDetected = recentScores.every((score) => score <= _lowScoreThreshold);

      if (streakDetected) {
        debugPrint("Consecutive low score streak DETECTED. Scores: $recentScores");
        if (mounted) {
          await prefs.setInt(_lastLowStreakAlertTimeKey, DateTime.now().millisecondsSinceEpoch);
          debugPrint("Low streak alert shown and new timestamp saved.");

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('마음 건강 알림', style: TextStyle(color: _sBlue, fontWeight: FontWeight.bold)),
              content: const Text('최근 감정 점수가 지속적으로 낮게 나타나고 있어요. 괜찮으신가요? 잠시 자신을 돌아보거나, 특별한 힐링 공간을 추천받아 보세요.'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              actionsAlignment: MainAxisAlignment.spaceAround,
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('괜찮아요', style: TextStyle(color: _sBlue)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _triggerHealingRecommendation();
                  },
                  child: Text('힐링 공간 추천', style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        debugPrint("No consecutive low score streak detected. Recent scores: $recentScores");
      }
    } catch (e) {
      debugPrint("Error checking low score streak: $e");
    }
  }

  Future<void> _getRecommendations({String? requestTypeFromTrigger}) async {
    if (!mounted) return;

    String timelineToSend = _controller.text.trim();


    if (requestTypeFromTrigger == 'healing') {
      if (timelineToSend.isEmpty) {
        timelineToSend = "몸과 마음의 치유가 필요한 상태입니다.";
      }
    } else {
      if (timelineToSend.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘의 기분을 입력해주세요.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // 로딩 화면 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(_sBlue),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "AI가 최적의 공간을 분석 중입니다...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _sBlue,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "잠시만 기다려 주세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final result = await ApiService.fetchRecommendation(
        timelineToSend,
        requestType: requestTypeFromTrigger,
      );

      // 성공 시 : ResultPage로 이동하기 직전에 로딩 다이얼로그 닫기
      if (mounted) {
        // 현재 컨텍스트에서 pop 할 수 있는 로딩 다이얼로그가 있는지 확인 후 닫기
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } else {
        return; // 위젯이 unmounted 상태면 더 이상 진행하지 않음
      }


      List<dynamic> detectedEmotionsList = result['detected_emotions'] as List<dynamic>? ?? [];
      String emotionsToStore = detectedEmotionsList.isNotEmpty
          ? detectedEmotionsList.map((e) => e.toString()).join(', ')
          : '알 수 없음';
      String weatherToStore = result['current_weather'] as String? ?? '정보 없음';
      final recommendations = List<Map<String, dynamic>>.from(result['recommendations'] ?? []);

      String firstEmotion = detectedEmotionsList.isNotEmpty ? detectedEmotionsList.first.toString().trim() : "";
      int currentNumericScore = _emotionScoreMap[firstEmotion] ?? 50;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('emotion_history')
          .add({
        'timestamp': Timestamp.now(),
        'timeline': timelineToSend,
        'emotion': emotionsToStore,
        'weather': weatherToStore,
        'numeric_score': currentNumericScore,
      });

      await _fetchEmotionHistory();

      if (requestTypeFromTrigger != 'healing') {
        await _checkAndNotifyLowStreak();
      }

      if (requestTypeFromTrigger == null) {
        _controller.clear();
      }

      if (!mounted) return; // 다시 한번 mounted 상태 확인
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultPage(
                user: widget.user,
                recommendations: recommendations,
                isHealingResult: (requestTypeFromTrigger == 'healing'), // isHealingResult 플래그 전달
              ),
        ),
      );

    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
      // 실패 시: 사용자에게 오류 알림 전 로딩 다이얼로그 닫기
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('추천을 가져오는 데 실패했습니다: ${e.toString()}'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _triggerHealingRecommendation() {
    if (!mounted) return;
    _getRecommendations(requestTypeFromTrigger: 'healing');
  }

  void _onBottomNavTapped(int index) {
    if (_selectedIndex == index && (index == 0)) return; // 홈 탭 중복 선택 방지
    if (index == 1) { // 감정 차트
      if (mounted) {
        setState(() { _selectedIndex = index; }); // 이동 전 선택된 탭 UI
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EmotionChartPage(user: widget.user)),
      ).then((_) {
        // EmotionChartPage에서 돌아왔을 때, 홈으로 선택 상태 복원
        if (mounted && _selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    } else if (index == 2) { // 마이페이지
      if (mounted) {
        setState(() { _selectedIndex = index; }); // 이동 전 선택된 탭 UI 변경
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MyPage(user: widget.user)),
      ).then((_) {
        // MyPage에서 돌아왔을 때, 홈으로 선택 상태 복원
        if (mounted && _selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    } else { // 홈 탭(index 0) 선택 시
      if(mounted) {
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? _sBlue : Colors.grey[600], size: 26),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? _sBlue : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getEmotionIcon(String? emotionString) {
    final firstEmotion = emotionString?.split(',').first.trim().toLowerCase();
    switch (firstEmotion) {
      case '기쁨': case '행복': case '신남':
      return Icons.sentiment_very_satisfied_outlined;
      case '설렘': return Icons.favorite_border_outlined;
      case '평온': case '차분함':
      return Icons.self_improvement_outlined;
      case '슬픔': case '우울':
      return Icons.sentiment_very_dissatisfied_outlined;
      case '분노': case '짜증':
      return Icons.sentiment_dissatisfied_outlined;
      case '불안': return Icons.sentiment_neutral_outlined;
      case '무기력': case '피곤':
      return Icons.battery_alert_outlined;
      case '집중필요': return Icons.psychology_outlined;
      case '혼자 있고 싶음': return Icons.person_outline;
      case '대화하고 싶음': return Icons.people_alt_outlined;
      case '휴식필요': return Icons.hotel_outlined;
      default: return Icons.sentiment_satisfied_alt_outlined;
    }
  }

  Future<bool> _onWillPop() async {
    if (_lastBackPressed == null ||
        DateTime.now().difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = DateTime.now();
      final bool? shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('앱 종료'),
          content: const Text('정말로 앱을 종료하시겠습니까?'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('아니오', style: TextStyle(color: _sBlue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('예', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
      );
      return shouldPop ?? false;
    }
    return false;
  }

  Widget _buildEmotionHistorySection() {
    if (_isLoadingHistory) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 30.0),
        child: CircularProgressIndicator(),
      ));
    }

    if (_emotionHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_edu_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('아직 기록된 감정이 없어요.', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              Text('오늘의 감정을 기록하고 공간을 추천 받아보세요!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _emotionHistory.length,
      itemBuilder: (context, index) {
        final entry = _emotionHistory[index];
        final timestamp = (entry['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final formattedDate = DateFormat('yyyy.MM.dd HH:mm').format(timestamp);
        final String displayedEmotion = entry['emotion'] as String? ?? '알 수 없음';
        final String displayedWeather = entry['weather'] as String? ?? '정보 없음';
        final emotionIcon = _getEmotionIcon(displayedEmotion);

        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: _cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(emotionIcon, color: _sBlue, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry['timeline'] as String? ?? '내용 없음',
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('날씨: $displayedWeather', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          Text('감정: $displayedEmotion', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double toggleWidth = MediaQuery.of(context).size.width * 0.75;
    if (toggleWidth > 400) toggleWidth = 400; // 최대 너비 제한
    double toggleHeight = 40.0; // 토글 스위치 높이
    double pillPadding = 4.0; // 알약 모양 표시기와 테두리 사이의 패딩
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _scaffoldBgColor,
        appBar: AppBar(
          backgroundColor: _sBlue,
          elevation: 0.5,
          centerTitle: true, // 제목을 가운데 정렬
          automaticallyImplyLeading: false,
          // AnimatedSwitcher를 사용하여 AppBar 제목에 애니메이션 적용
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700), // 애니메이션 지속 시간
            transitionBuilder: (Widget child, Animation<double> animation) {
              // FadeTransition과 SlideTransition을 함께 사용하여 부드러운 효과
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3), // 아래에서 위로 올라오는 효과
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _appBarTexts[_currentAppBarTextIndex],
              key: ValueKey<int>(_currentAppBarTextIndex), // 인덱스를 Key로 사용
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_outlined, color: Colors.white),
              tooltip: '로그아웃',
              onPressed: () async {
                final bool? confirmLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말로 로그아웃 하시겠습니까?'),
                    actionsAlignment: MainAxisAlignment.spaceEvenly,
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('취소', style: TextStyle(color: _sBlue)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                );
                if (confirmLogout == true) {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                        (route) => false,
                  );
                }
              },
            )
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentInputMode == InputMode.emotion
                            ? '오늘 하루, 어떤 감정을 느끼셨나요?'
                            : '어떤 공간을 찾고 계신가요?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _sBlue),
                      ),
                      const SizedBox(height: 16), // 제목과 토글 사이 간격

                      // 커스텀 토글 스위치 UI
                      Center(
                        child: Container(
                          width: toggleWidth,
                          height: toggleHeight,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200, // 토글 전체 배경색
                            borderRadius: BorderRadius.circular(toggleHeight / 2), // 둥근 모서리
                          ),
                          child: Stack(
                            children: [
                              // 슬라이딩 되는 알약 모양 표시기
                              AnimatedAlign(
                                alignment: _currentInputMode == InputMode.emotion
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                duration: const Duration(milliseconds: 250), // 애니메이션 속도
                                curve: Curves.easeInOut, // 애니메이션 커브
                                child: Container(
                                  width: (toggleWidth / 2) - (pillPadding /2) , // 알약 너비
                                  height: toggleHeight - (pillPadding * 2), // 알약 높이
                                  margin: EdgeInsets.all(pillPadding),
                                  decoration: BoxDecoration(
                                      color: _sBlue, // 선택된 옵션 배경색
                                      borderRadius: BorderRadius.circular((toggleHeight - (pillPadding*2)) / 2),
                                      boxShadow: [ // 입체감을 위한 그림자
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                  ),
                                ),
                              ),
                              // 두 개의 탭 영역
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (mounted && _currentInputMode != InputMode.emotion) {
                                          setState(() {
                                            _currentInputMode = InputMode.emotion;
                                          });
                                        }
                                      },
                                      child: Container( // 탭 영역 명확화를 위한 Container
                                        color: Colors.transparent, // 터치 영역 확보
                                        alignment: Alignment.center,
                                        child: Text(
                                          '감정 기반',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            // 선택된 텍스트는 흰색
                                            color: _currentInputMode == InputMode.emotion
                                                ? Colors.white
                                                : _sBlue.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (mounted && _currentInputMode != InputMode.purpose) {
                                          setState(() {
                                            _currentInputMode = InputMode.purpose;
                                          });
                                        }
                                      },
                                      child: Container(
                                        color: Colors.transparent, // 터치 영역 확보
                                        alignment: Alignment.center,
                                        child: Text(
                                          '목적/질문 기반',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _currentInputMode == InputMode.purpose
                                                ? Colors.white
                                                : _sBlue.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      TextField(
                        controller: _controller,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: _currentInputMode == InputMode.emotion
                              ? '자유롭게 감정이나 있었던 일을 적어주세요.\n예) 오늘 날씨가 좋아서 기분이 상쾌했다!'
                              : '찾고 있는 공간에 대해 질문하거나 설명해주세요.\n예) 팀플하기 좋은 카페 알려줘\n예) 배고픈데 밥 먹을 수 있는 곳 있어?',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.4),
                          filled: true,
                          fillColor: _scaffoldBgColor.withOpacity(0.7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: _sBlue, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome_outlined, color: Colors.white, size: 20),
                        label: const Text(
                          '맞춤 공간 추천받기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        // onPressed CallBack
                        onPressed: () {
                          String? currentRequestType; // Default is Null
                          if (_currentInputMode == InputMode.purpose) {
                            currentRequestType = 'direct_query'; // 목적/질문 기반 모드일 경우
                          }
                          _getRecommendations(requestTypeFromTrigger: currentRequestType);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _sBlue,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // 위젯 간의 간격을 위한 SizedBox
                ElevatedButton(
                  onPressed: () {
                    _triggerHealingRecommendation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // 테스트 버튼임을 구분하기 위한 색상
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    foregroundColor: Colors.white, // 버튼 텍스트 색상
                  ),
                  child: const Text('임시: 힐링 추천 테스트 실행'),
                ),
                // 임시 버튼 추가 끝점
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📌 내 감정 히스토리', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _sBlue)),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: _sBlue),
                      tooltip: '새로고침',
                      onPressed: _fetchEmotionHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEmotionHistorySection(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          elevation: 10.0,
          color: _cardColor,
          shape: const CircularNotchedRectangle(),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 60, // 하단 네비게이션 바 높이
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, // 아이템들을 균등하게 배치
              children: <Widget>[
                _buildBottomNavItem(
                  icon: _selectedIndex == 0 ? Icons.home_filled : Icons.home_outlined,
                  label: '홈',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _onBottomNavTapped(0),
                ),
                _buildBottomNavItem(
                  icon: _selectedIndex == 1 ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
                  label: '감정 차트',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _onBottomNavTapped(1),
                ),
                // 마이페이지 탭
                _buildBottomNavItem(
                  icon: _selectedIndex == 2 ? Icons.person_rounded : Icons.person_outline_rounded,
                  label: '마이페이지',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _onBottomNavTapped(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}