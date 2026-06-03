import 'dart:convert';
import '../config/api_config.dart';
import '../models/daily_question_model.dart';
import 'api_client.dart';

class DailyQuestionService {
  static final String _baseUrl = ApiConfig.baseUrl;

  static Future<DailyQuestionResponse> getTodayQuestion() async {
    final response = await ApiClient.get(
      Uri.parse('$_baseUrl/daily-question/today'),
    );

    if (response.statusCode == 200) {
      return DailyQuestionResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar a pergunta do dia');
    }
  }

  static Future<AnswerSubmissionResponse> submitAnswer(
    String questionId,
    String selectedOption,
  ) async {
    final response = await ApiClient.post(
      Uri.parse('$_baseUrl/daily-question/answer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question_id': questionId,
        'selected_option': selectedOption,
      }),
    );

    if (response.statusCode == 200) {
      return AnswerSubmissionResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Falha ao submeter resposta');
    }
  }

  static Future<StreakResponse> getStreak() async {
    final response = await ApiClient.get(
      Uri.parse('$_baseUrl/daily-question/streak'),
    );

    if (response.statusCode == 200) {
      return StreakResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar o streak');
    }
  }
}
