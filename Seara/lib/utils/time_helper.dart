import '../services/time_service.dart';

String formatRelativeTime(DateTime dateTime) {
  final now = TimeService.now;
  final difference = now.difference(dateTime);

  if (difference.inDays >= 365) {
    final years = (difference.inDays / 365).floor();
    return '${years}a';
  } else if (difference.inDays >= 30) {
    final months = (difference.inDays / 30).floor();
    return '${months}mês';
  } else if (difference.inDays >= 7) {
    final weeks = (difference.inDays / 7).floor();
    return '${weeks}sem';
  } else if (difference.inDays >= 1) {
    return '${difference.inDays}d';
  } else if (difference.inHours >= 1) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes >= 1) {
    return '${difference.inMinutes}min';
  } else {
    return 'agora';
  }
}
