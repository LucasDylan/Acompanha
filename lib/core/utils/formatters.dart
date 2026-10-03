import 'package:intl/intl.dart';

/// "R$ 120,00" (or "R$ 120" with [compact] when there are no cents).
String formatMoney(double amount, String currency, {bool compact = false}) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.simpleCurrency(
    locale: 'pt_BR',
    name: currency.toUpperCase(),
    decimalDigits: compact && whole ? 0 : 2,
  ).format(amount);
}

/// "45 min", "1h", "1h30".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// "sáb., 4 de out." — short weekday + day + month.
String formatDayMonth(DateTime date) =>
    DateFormat("EEE, d 'de' MMM", 'pt_BR').format(date);

/// "sábado, 4 de outubro".
String formatLongDate(DateTime date) =>
    DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(date);

String formatTime(DateTime date) => DateFormat('HH:mm').format(date);

/// Chat-list style timestamp: time today, "Ontem", or the date.
String formatRelativeDay(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return formatTime(date);
  if (diff == 1) return 'Ontem';
  if (diff < 7) return DateFormat('EEE', 'pt_BR').format(date);
  return DateFormat('dd/MM/yy').format(date);
}
