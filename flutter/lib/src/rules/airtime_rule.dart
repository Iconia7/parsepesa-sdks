import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class AirtimeRule implements ParseRule {
  @override
  String get transactionType => 'airtime_purchase';

  @override
  String get version => '1.1.0';

  @override
  double get priority => 1.4;

  // Pattern 1: Full format with ID and balance
  static final RegExp _pattern1 = RegExp(
    r'([A-Z0-9]{8,12})\s+Confirmed\.\s+Ksh([\d,]+\.?\d*)\s+airtime\s+(?:purchased|bought)(?:\s+for\s+\S+)?\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.?(?:\s+New\s+M-PESA\s+balance\s+is\s+Ksh([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  // Pattern 2: "You have bought airtime of Ksh... on ..."
  static final RegExp _pattern2 = RegExp(
    r'You\s+have\s+(?:bought|purchased)\s+airtime\s+(?:of\s+)?Ksh([\d,]+\.?\d*)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    final m1 = _pattern1.firstMatch(rawSms);
    if (m1 != null) {
      return _build(
        id: m1.group(1)!,
        amount: m1.group(2)!,
        date: m1.group(3)!,
        time: m1.group(4)!,
        balanceStr: m1.group(5),
      );
    }

    final m2 = _pattern2.firstMatch(rawSms);
    if (m2 != null) {
      return _build(
        id: 'AT${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        amount: m2.group(1)!,
        date: m2.group(2)!,
        time: m2.group(3)!,
        balanceStr: null,
      );
    }

    return null;
  }

  ParseResult? _build({
    required String id,
    required String amount,
    required String date,
    required String time,
    String? balanceStr,
  }) {
    try {
      final double parsedAmount = double.parse(amount.replaceAll(',', ''));
      final double? balance = balanceStr != null ? double.tryParse(balanceStr.replaceAll(',', '')) : null;

      DateTime timestamp;
      try {
        timestamp = DateFormat('d/M/yy h:mm a').parse('$date ${time.trim()}');
      } catch (_) {
        timestamp = DateFormat('d/M/yyyy h:mm a').parse('$date ${time.trim()}');
      }

      return ParseResult(
        success: true,
        confidence: 1.0,
        parserVersion: version,
        data: Transaction(
          transactionId: id,
          type: transactionType,
          amount: parsedAmount,
          currency: 'KES',
          counterparty: 'Safaricom Airtime',
          balance: balance,
          timestamp: timestamp,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
