import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatShort(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatFull(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  static String formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(date.year, date.month, date.day);
    final difference = dueDay.difference(today).inDays;

    if (difference < 0) {
      return 'Overdue by ${-difference} day${-difference > 1 ? 's' : ''}';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $difference days';
    }
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static bool isDueSoon(DateTime date, {int hoursThreshold = 24}) {
    final now = DateTime.now();
    final difference = date.difference(now).inHours;
    return difference >= 0 && difference <= hoursThreshold;
  }
}
