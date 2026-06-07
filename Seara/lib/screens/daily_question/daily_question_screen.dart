import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/time_service.dart';
import '../../models/daily_question_model.dart';
import '../../services/daily_question_service.dart';

class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  DailyQuestionResponse? _data;
  AnswerSubmissionResponse? _submission;
  StreakResponse? _streak;
  String? _selectedOption;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFromCache().then((_) {
      _fetchData();
      _fetchStreak();
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('daily_question_cache');
      
      if (cachedJson != null) {
        final data = DailyQuestionResponse.fromJson(jsonDecode(cachedJson));
        if (!mounted) return;
        setState(() {
          _data = data;
          if (data.answeredToday && data.userAnswer != null) {
            _selectedOption = data.userAnswer!.selectedOption;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
  }

  Future<void> _saveToCache(DailyQuestionResponse data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('daily_question_cache', jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  Future<void> _fetchStreak() async {
    try {
      final streakData = await DailyQuestionService.getStreak();
      if (!mounted) return;
      setState(() {
        _streak = streakData;
      });
    } catch (e) {
      // Silently fail as per requirements
      debugPrint('Streak fetch failed: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await DailyQuestionService.getTodayQuestion();
      if (!mounted) return;
      _saveToCache(data);
      setState(() {
        _data = data;
        if (data.answeredToday && data.userAnswer != null) {
          _selectedOption = data.userAnswer!.selectedOption;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível carregar a pergunta de hoje.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAnswer(String option) async {
    if (_data == null || _data!.answeredToday || _submission != null || _isSubmitting) return;

    setState(() {
      _selectedOption = option;
      _isSubmitting = true;
    });

    try {
      final result = await DailyQuestionService.submitAnswer(
        _data!.question.id,
        option,
      );
      if (!mounted) return;
      setState(() {
        _submission = result;
        _isSubmitting = false;
      });
      _fetchStreak();
      // Atualizar cache após responder
      if (_data != null) {
        final updatedData = DailyQuestionResponse(
          question: _data!.question,
          answeredToday: true,
          userAnswer: UserAnswer(
            selectedOption: option,
            isCorrect: result.isCorrect,
            answeredAt: TimeService.now.toIso8601String(),
          ),
          globalAccuracy: result.globalAccuracy,
          explanation: result.explanation,
          correctOption: result.correctOption,
        );
        _saveToCache(updatedData);
      }
    } catch (e) {
      if (!mounted) return;
      
      final errorMsg = e.toString();
      if (errorMsg.contains('já respondeu') || errorMsg.contains('Already answered')) {
        _fetchData(); // Sincroniza com o estado do servidor
        return;
      }

      setState(() {
        _isSubmitting = false;
        _selectedOption = null; // Reset selection on error to allow retry
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar a resposta. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getOptionColor(String option, ColorScheme cs) {
    final isSelected = _selectedOption == option;
    final isAnswered = _data?.answeredToday ?? false;
    
    // Se ainda não houve resposta
    if (!isAnswered && _submission == null) {
      return isSelected ? cs.primaryContainer : cs.surfaceContainerHighest;
    }

    // Se já tinha respondido antes de carregar a página
    if (isAnswered && _data?.userAnswer != null) {
      if (_data!.userAnswer!.selectedOption == option) {
        return _data!.userAnswer!.isCorrect ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8);
      }
      
      if (_data!.correctOption == option) {
        return Colors.green.withOpacity(0.8);
      }

      return cs.surfaceContainerHighest.withOpacity(0.5);
    }

    // Se acabou de responder agora
    if (_submission != null) {
      if (isSelected) {
        return _submission!.isCorrect ? Colors.green : Colors.red;
      }
      
      // Se o backend retornasse a correta, pintaríamos aqui
      if (_submission!.correctOption == option) {
        return Colors.green;
      }
      
      return cs.surfaceContainerHighest.withOpacity(0.5);
    }

    return cs.surfaceContainerHighest;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pergunterrima do Dia'),
        centerTitle: true,
        actions: [
          if (_streak != null) _buildStreakIndicator(cs),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(cs)
          : _errorMessage != null
              ? _buildErrorState(cs)
              : (_data == null)
                  ? _buildEmptyState(cs)
                  : _buildContent(cs),
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'A carregar pergunta do dia...',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Não foi possível carregar a pergunta de hoje.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '📚',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'Não existe pergunta disponível para hoje.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _fetchData,
              child: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakIndicator(ColorScheme cs) {
    final hasAnswered = _streak?.answeredToday ?? false;
    final streakCount = _streak?.streak ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Tooltip(
        message: 'Responda todos os dias para manter a sequência.',
        triggerMode: TooltipTriggerMode.longPress, // Mobile compatibility
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAnswered)
              const Text('🔥', style: TextStyle(fontSize: 18))
            else
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
                child: const Text('🔥', style: TextStyle(fontSize: 18)),
              ),
            const SizedBox(width: 4),
            Text(
              '$streakCount ${streakCount == 1 ? 'dia' : 'dias'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasAnswered ? cs.primary : cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final q = _data!.question;
    final isAnswered = _data!.answeredToday || _submission != null;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (q.topic != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    q.topic!.toUpperCase(),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(
                q.question,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              _buildOption('A', q.optionA, cs, isAnswered),
              _buildOption('B', q.optionB, cs, isAnswered),
              _buildOption('C', q.optionC, cs, isAnswered),
              _buildOption('D', q.optionD, cs, isAnswered),
              
              const SizedBox(height: 12),
              
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isAnswered ? 1.0 : 0.0,
                child: isAnswered ? _buildFeedback(cs) : const SizedBox.shrink(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_isSubmitting)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildOption(String code, String text, ColorScheme cs, bool isAnswered) {
    final color = _getOptionColor(code, cs);
    final isSelected = _selectedOption == code;
    final canInteract = !isAnswered && !_isSubmitting;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AnimatedScale(
        scale: isSelected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canInteract ? () => _handleAnswer(code) : null,
            splashColor: canInteract ? null : Colors.transparent,
            highlightColor: canInteract ? null : Colors.transparent,
            hoverColor: canInteract ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAnswered && isSelected
                      ? ((_submission?.isCorrect ??
                              _data?.userAnswer?.isCorrect ??
                              false)
                          ? Colors.green
                          : Colors.red)
                      : (isSelected ? cs.primary : Colors.transparent),
                  width: 2,
                ),
                boxShadow: isSelected && !isAnswered
                    ? [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : cs.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isAnswered && isSelected)
                    Icon(
                      (_submission?.isCorrect ??
                              _data?.userAnswer?.isCorrect ??
                              false)
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback(ColorScheme cs) {
    final explanation = _submission?.explanation ?? _data?.explanation ?? 'Você já respondeu a esta pergunta hoje.';
    final accuracy = _submission?.globalAccuracy ?? _data?.globalAccuracy;
    final isCorrect = _submission?.isCorrect ?? _data?.userAnswer?.isCorrect ?? false;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey('explanation_$isCorrect'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCorrect 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isCorrect ? 'Excelente!' : 'Não foi desta vez',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 15, 
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (accuracy != null) ...[
          const SizedBox(height: 24),
          _buildGlobalStats(accuracy, cs),
        ],
      ],
    );
  }

  Widget _buildGlobalStats(double accuracy, ColorScheme cs) {
    String message;
    if (accuracy >= 80) {
      message = "Muita gente acertou esta.";
    } else if (accuracy >= 50) {
      message = "Foi uma pergunta equilibrada.";
    } else {
      message = "Esta pergunta enganou muita gente.";
    }

    final roundedAccuracy = accuracy.round();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: 1.0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              'A comunidade respondeu:',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$roundedAccuracy% acertaram',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
