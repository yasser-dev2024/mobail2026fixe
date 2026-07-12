import 'package:intl/intl.dart';

class AppFormatters {
  static String currency(double amount, {String symbol = 'ر.س'}) {
    final formatter = NumberFormat('#,##0.00', 'ar');
    return '${formatter.format(amount)} $symbol';
  }

  static String number(int value) {
    return NumberFormat('#,###', 'ar').format(value);
  }

  static String date(DateTime date) {
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(date);
  }

  static String dateFromMs(int ms) {
    return date(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  static String dateTimeFromMs(int ms) {
    return dateTime(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  static String timeAgo(int ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - ms;
    if (diff < 60000) return 'الآن';
    if (diff < 3600000) return 'منذ ${(diff / 60000).floor()} دقيقة';
    if (diff < 86400000) return 'منذ ${(diff / 3600000).floor()} ساعة';
    if (diff < 2592000000) return 'منذ ${(diff / 86400000).floor()} يوم';
    return dateFromMs(ms);
  }

  static String warrantyPeriodLabel(String type) {
    switch (type) {
      case 'none':
        return 'بدون ضمان';
      case '7_days':
        return '7 أيام';
      case '30_days':
        return '30 يوماً';
      case '90_days':
        return '90 يوماً';
      case '6_months':
        return '6 أشهر';
      case '1_year':
        return 'سنة';
      case '2_years':
        return 'سنتين';
      case 'custom':
        return 'مخصص';
      default:
        return type;
    }
  }

  static String paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'نقدي';
      case 'card':
        return 'شبكة';
      case 'transfer':
        return 'تحويل';
      case 'credit':
        return 'آجل';
      default:
        return method;
    }
  }

  static String categoryLabel(String key) {
    switch (key) {
      case 'phones':
        return 'جوالات';
      case 'screens':
        return 'شاشات';
      case 'batteries':
        return 'بطاريات';
      case 'chargers':
        return 'شواحن';
      case 'earphones':
        return 'سماعات';
      case 'cases':
        return 'كفرات';
      case 'spare_parts':
        return 'قطع غيار';
      case 'services':
        return 'خدمات';
      case 'other':
        return 'أخرى';
      default:
        return key;
    }
  }
}
