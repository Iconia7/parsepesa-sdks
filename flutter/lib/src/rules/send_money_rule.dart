import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class SendMoneyRule implements ParseRule {
  @override
  String get transactionType => 'send_money';

  @override
  String get version => '1.1.0';

  @override
  double get priority => 1.0;

  // Pattern 1: Full format with ID: "ABC123DEF Confirmed. Ksh500.00 sent to NAME on DATE at TIME. New M-PESA balance is KshX."
  static final RegExp _pattern1 = RegExp(
    r'([A-Z0-9]{8,12})\s+Confirmed\.\s+Ksh([\d,]+\.?\d*)\s+sent\s+to\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.?(?:\s+New\s+M-PESA\s+balance\s+is\s+Ksh([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  // Pattern 2: No leading ID: "Confirmed. Ksh500.00 sent to NAME on DATE at TIME. New M-PESA balance is KshX."
  static final RegExp _pattern2 = RegExp(
    r'Confirmed\.\s+Ksh([\d,]+\.?\d*)\s+sent\s+to\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.?(?:\s+New\s+M-PESA\s+balance\s+is\s+Ksh([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    // Try pattern 1 (with ID)
    final m1 = _pattern1.firstMatch(rawSms);
    if (m1 != null) {
      return _build(
        id: m1.group(1)!,
        amount: m1.group(2)!,
        counterparty: m1.group(3)!,
        date: m1.group(4)!,
        time: m1.group(5)!,
        balanceStr: m1.group(6),
      );
    }

    // Try pattern 2 (no ID)
    final m2 = _pattern2.firstMatch(rawSms);
    if (m2 != null) {
      return _build(
        id: 'SM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        amount: m2.group(1)!,
        counterparty: m2.group(2)!,
        date: m2.group(3)!,
        time: m2.group(4)!,
        balanceStr: m2.group(5),
      );
    }

    return null;
  }

  ParseResult? _build({
    required String id,
    required String amount,
    required String counterparty,
    required String date,
    required String time,
    String? balanceStr,
  }) {
    try {
      final double parsedAmount = double.parse(amount.replaceAll(',', ''));
      final double? balance = balanceStr != null ? double.tryParse(balanceStr.replaceAll(',', '')) : null;

      // Extract phone number if present in counterparty
      final phoneMatch = RegExp(r'(\d{10,12})').firstMatch(counterparty);
      String? phoneNumber = phoneMatch?.group(1);
      String cleanCounterparty = counterparty.replaceAll(RegExp(r'\d{10,12}'), '').trim();

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
          counterparty: cleanCounterparty.isEmpty ? counterparty : cleanCounterparty,
          phoneNumber: phoneNumber,
          balance: balance,
          timestamp: timestamp,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
