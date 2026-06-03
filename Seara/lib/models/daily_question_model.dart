class DailyQuestion {
  final String id;
  final String date;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String? topic;

  DailyQuestion({
    required this.id,
    required this.date,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    this.topic,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) {
    return DailyQuestion(
      id: json['id'],
      date: json['date'] ?? '',
      question: json['question'],
      optionA: json['option_a'],
      optionB: json['option_b'],
      optionC: json['option_c'],
      optionD: json['option_d'],
      topic: json['topic'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'question': question,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'topic': topic,
    };
  }
}

class UserAnswer {
  final String selectedOption;
  final bool isCorrect;
  final String answeredAt;

  UserAnswer({
    required this.selectedOption,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory UserAnswer.fromJson(Map<String, dynamic> json) {
    return UserAnswer(
      selectedOption: json['selected_option'],
      isCorrect: json['is_correct'],
      answeredAt: json['answered_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selected_option': selectedOption,
      'is_correct': isCorrect,
      'answered_at': answeredAt,
    };
  }
}

class DailyQuestionResponse {
  final DailyQuestion question;
  final bool answeredToday;
  final UserAnswer? userAnswer;
  final double? globalAccuracy;
  final String? explanation;
  final String? correctOption;

  DailyQuestionResponse({
    required this.question,
    required this.answeredToday,
    this.userAnswer,
    this.globalAccuracy,
    this.explanation,
    this.correctOption,
  });

  factory DailyQuestionResponse.fromJson(Map<String, dynamic> json) {
    return DailyQuestionResponse(
      question: DailyQuestion.fromJson(json['question']),
      answeredToday: json['answeredToday'],
      userAnswer: json['userAnswer'] != null
          ? UserAnswer.fromJson(json['userAnswer'])
          : null,
      globalAccuracy: json['globalAccuracy'] != null
          ? (json['globalAccuracy'] as num).toDouble()
          : null,
      explanation: json['explanation'],
      correctOption: json['correctOption'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question.toJson(),
      'answeredToday': answeredToday,
      'userAnswer': userAnswer?.toJson(),
      'globalAccuracy': globalAccuracy,
      'explanation': explanation,
      'correctOption': correctOption,
    };
  }
}

class AnswerSubmissionResponse {
  final bool isCorrect;
  final String explanation;
  final double globalAccuracy;
  final String? correctOption; // Adicionado para suportar feedback visual da correta

  AnswerSubmissionResponse({
    required this.isCorrect,
    required this.explanation,
    required this.globalAccuracy,
    this.correctOption,
  });

  factory AnswerSubmissionResponse.fromJson(Map<String, dynamic> json) {
    return AnswerSubmissionResponse(
      isCorrect: json['isCorrect'],
      explanation: json['explanation'] ?? '',
      globalAccuracy: (json['globalAccuracy'] as num).toDouble(),
      correctOption: json['correctOption'], // Opcional, dependendo do backend
    );
  }
}

class StreakResponse {
  final int streak;
  final bool answeredToday;

  StreakResponse({
    required this.streak,
    required this.answeredToday,
  });

  factory StreakResponse.fromJson(Map<String, dynamic> json) {
    return StreakResponse(
      streak: json['streak'] ?? 0,
      answeredToday: json['answeredToday'] ?? false,
    );
  }
}
