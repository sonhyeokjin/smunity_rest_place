import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';


class EmotionChartPage extends StatefulWidget {
  final User user;
  const EmotionChartPage({Key? key, required this.user}) : super(key: key);

  @override
  State<EmotionChartPage> createState() => _EmotionChartPageState();
}

class _EmotionChartPageState extends State<EmotionChartPage> {
  List<FlSpot> _emotionScores = [];
  List<String> _timestamps = [];
  List<String> _emotionsAtPoints = [];

  bool _isLoading = true;
  double _bottomTitleLabelSkipInterval = 1.0;
  final double _xStep = 60.0;

  final Color _appPrimaryColor = const Color(0xFF002D72);
  final Color _appSecondaryColor = Colors.blueAccent;

  final Map<String, int> _emotionScoreMap = {
    '기쁨': 80, '행복': 90, '신남': 85, '평온': 70,
    '만족': 75, '슬픔': 30, '우울': 20, '불안': 35,
    '짜증': 40, '분노': 25, '피곤': 45, '혼란': 50,
    '무기력': 15,
  };

  final ScrollController _chartScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchEmotionHistory();
  }

  void _scrollToEnd([bool animated = true]) {
    if (_chartScrollController.hasClients && _emotionScores.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _chartScrollController.hasClients) {
          if (animated) {
            _chartScrollController.animateTo(
              _chartScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } else {
            _chartScrollController.jumpTo(_chartScrollController.position.maxScrollExtent);
          }
        }
      });
    }
  }

  Future<void> _fetchEmotionHistory() async {
    if (!mounted) return;
    if (!_isLoading) {
      setState(() { _isLoading = true; });
    }

    try {
      final uid = widget.user.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('emotion_history')
          .orderBy('timestamp')
          .get();

      List<FlSpot> tempScores = [];
      List<String> tempTimes = [];
      List<String> tempEmotions = [];

      for (var i = 0; i < snapshot.docs.length; i++) {
        var data = snapshot.docs[i].data();
        var emotionRaw = data['emotion'] as String? ?? '';
        var mainEmotion = emotionRaw.split(',').first.trim();
        var ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        int score = _emotionScoreMap[mainEmotion] ?? 50;

        tempScores.add(FlSpot(i.toDouble() * _xStep, score.toDouble()));
        tempTimes.add(DateFormat('MM/dd HH:mm').format(ts));
        tempEmotions.add(mainEmotion);
      }

      if (!mounted) return;
      setState(() {
        _emotionScores = tempScores;
        _timestamps = tempTimes;
        _emotionsAtPoints = tempEmotions;
        if (_timestamps.isNotEmpty) {
          _bottomTitleLabelSkipInterval = (_timestamps.length / 7.0).ceilToDouble().clamp(1.0, double.infinity);
          if (_timestamps.length <= 7) {
            _bottomTitleLabelSkipInterval = 1.0;
          }
        } else {
          _bottomTitleLabelSkipInterval = 1.0;
        }
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint("Error fetching emotion history for chart: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('감정 기록을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Color(0xff75729e), fontWeight: FontWeight.bold, fontSize: 12);
    String text;
    if (value % 20 == 0 && value >= 0 && value <= 100) {
      text = value.toInt().toString();
    } else {
      return Container();
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: Text(text, style: style, textAlign: TextAlign.center));
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Color(0xff75729e), fontWeight: FontWeight.bold, fontSize: 10);
    final int index = (value / _xStep).round().toInt();
    Widget textWidget;

    if (index >= 0 && index < _timestamps.length) {
      textWidget = Text(_timestamps[index], style: style, textAlign: TextAlign.center);
    } else {
      textWidget = const Text('', style: style);
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10.0,
      angle: (_timestamps.length > 10 && _xStep < 60) ? 3.141592653589793 / 4 : 0, // 45도
      child: textWidget,
    );
  }

  Widget _buildEmotionMappingInfo() {
    // 점수 기준으로 정렬된 감정 맵 (높은 점수 -> 낮은 점수)
    var sortedEmotions = _emotionScoreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "감정 점수 가이드",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _appPrimaryColor),
          ),
          const SizedBox(height: 12), // 제목과 목록 사이 간격
          Column(
            children: sortedEmotions.map((entry) {
              IconData iconData;
              Color iconColor;
              // 점수 범위에 따라 아이콘 및 색상 결정 (기존 로직 유지)
              if (entry.value >= 70) {
                iconData = Icons.sentiment_very_satisfied;
                iconColor = Colors.green.shade400;
              } else if (entry.value >= 40) {
                iconData = Icons.sentiment_neutral;
                iconColor = Colors.orange.shade400;
              } else {
                iconData = Icons.sentiment_very_dissatisfied;
                iconColor = Colors.red.shade400;
              }

              // ✅ 각 감정 항목을 Card와 ListTile을 사용하여 한 줄로 표시
              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4.0), // 카드 간 세로 간격
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                child: ListTile(
                  leading: Icon(iconData, color: iconColor, size: 28), // 아이콘 크기 약간 키움
                  title: Text(
                    entry.key, // 감정 이름
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    "${entry.value}점", // 해당 감정의 점수
                    style: TextStyle(
                        fontSize: 15,
                        color: _appPrimaryColor, // 점수 텍스트 색상
                        fontWeight: FontWeight.bold),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // ListTile 내부 패딩
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double calculatedChartWidth = _emotionScores.isNotEmpty
        ? (_emotionScores.length.toDouble() * _xStep) + _xStep
        : screenWidth;
    final double chartContainerWidth = calculatedChartWidth < screenWidth && _emotionScores.isNotEmpty
        ? screenWidth
        : calculatedChartWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 변화 그래프', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _appPrimaryColor,
        elevation: 2.0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _appPrimaryColor))
          : _emotionScores.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text("감정 기록이 아직 없어요.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text("홈 화면에서 오늘의 감정을 기록해보세요!", style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _chartScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: chartContainerWidth,
                    padding: const EdgeInsets.only(top: 24, bottom: 12, right: 20, left: 8),
                    child: LineChart(
                      LineChartData(
                        backgroundColor: Colors.white,
                        minX: 0,
                        maxX: (_emotionScores.isNotEmpty ? (_emotionScores.length - 1) : 0).toDouble() * _xStep,
                        minY: 0,
                        maxY: 100,
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (LineBarSpot touchedSpot) => _appPrimaryColor.withOpacity(0.85),
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                              return touchedBarSpots.map((barSpot) {
                                final flSpot = barSpot;
                                final int index = (flSpot.x / _xStep).round().toInt();
                                if (index < 0 || index >= _timestamps.length) return null;

                                String emotionAtPoint = _emotionsAtPoints.length > index ? _emotionsAtPoints[index] : "";

                                return LineTooltipItem(
                                  '${_timestamps[index]}\n',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  children: [
                                    TextSpan(
                                      text: flSpot.y.toStringAsFixed(0),
                                      style: TextStyle(color: Colors.yellow[600], fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                    const TextSpan(text: ' 점', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 11)),
                                    if (emotionAtPoint.isNotEmpty)
                                      TextSpan(text: '\n감정: $emotionAtPoint', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                                  ],
                                  textAlign: TextAlign.left,
                                );
                              }).toList();
                            },
                          ),
                          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                            return spotIndexes.map((index) {
                              return TouchedSpotIndicatorData(
                                FlLine(color: _appSecondaryColor.withOpacity(0.7), strokeWidth: 3),
                                FlDotData(
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 7,
                                      color: _appSecondaryColor,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                              );
                            }).toList();
                          },
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300.withOpacity(0.7),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            axisNameWidget: Text("감정 점수", style: TextStyle(fontSize: 11, color: _appPrimaryColor, fontWeight: FontWeight.bold)),
                            axisNameSize: 22,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 20,
                              getTitlesWidget: _leftTitleWidgets,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: Padding(
                              padding: const EdgeInsets.only(top:10.0),
                              child: Text("기록 시간", style: TextStyle(fontSize: 11, color: _appPrimaryColor, fontWeight: FontWeight.bold)),
                            ),
                            axisNameSize: 30,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: _bottomTitleLabelSkipInterval * _xStep,
                              getTitlesWidget: _bottomTitleWidgets,
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _emotionScores,
                            isCurved: true,
                            curveSmoothness: 0.4,
                            preventCurveOverShooting: true,
                            preventCurveOvershootingThreshold: 10.0,
                            gradient: LinearGradient(
                              colors: [_appSecondaryColor.withOpacity(0.8), _appPrimaryColor.withOpacity(0.6)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            barWidth: 3.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 5,
                                  color: barData.gradient?.colors.first ?? _appSecondaryColor,
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  _appSecondaryColor.withOpacity(0.3),
                                  _appPrimaryColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 200),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildEmotionMappingInfo(),
            ],
          ),
        ),
      ),
    );
  }
}