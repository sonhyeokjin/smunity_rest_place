import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class ApiService {
  static Future<Map<String, dynamic>> fetchRecommendation(
      String timeline, {
        String? requestType,
      }) async {
    final String localApiBaseUrl = '192.168.0.171:5050';

    // URL 생성
    final url = Uri.parse('http://$localApiBaseUrl/recommend');

    Map<String, dynamic> requestBody = {
      'timeline': timeline,
    };

    if (requestType != null && requestType.isNotEmpty) {
      requestBody['request_type'] = requestType;
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        return jsonDecode(responseBody) as Map<String, dynamic>;
      } else {
        String errorMessage = '추천 요청 실패: ${response.statusCode}';
        try {
          final String errorBody = utf8.decode(response.bodyBytes);
          final decodedError = jsonDecode(errorBody);
          if (decodedError is Map && decodedError.containsKey('error')) {
            errorMessage += '\n오류 메시지: ${decodedError['error']}';
          } else {
            errorMessage += '\n응답: $errorBody';
          }
        } catch (e) {
          errorMessage += '\n(오류 응답 본문 디코딩 실패), Raw: ${response.bodyBytes.isNotEmpty ? response.body.substring(0, math.min(response.body.length, 100)) : "Empty Body"}';
        }
        debugPrint("ApiService Error: $errorMessage"); // 디버그 콘솔에 오류 출력
        throw Exception(errorMessage);
      }
    } catch (e) {
      // 네트워크 연결 오류 등 http.post 자체에서 발생할 수 있는 예외 처리
      debugPrint("ApiService Network/Request Error: $e");
      throw Exception('서버 연결에 실패했습니다. 네트워크 상태를 확인해주세요: $e');
    }
  }
}