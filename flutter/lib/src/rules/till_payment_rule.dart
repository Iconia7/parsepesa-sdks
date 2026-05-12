import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class TillPaymentRule implements ParseRule {
  @override
  String get transactionType => 'till_payment';

  @override
  String get version => '1.0.0';

  @override
  double get priority => 1.1; // Higher priority than send_money to avoid overlap if similar

  static final RegExp _pattern = RegExp(
    r'([A-Z0-9]{8,12})\s+Confirmed\.\s+Ksh([\d,]+\.?\d*)\s+paid\s+to\s+(.+?)\.?\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.?(?:\s+New\s+M-PESA\s+balance\s+is\s+Ksh([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    final match = _pattern.firstMatch(rawSms);
    if (match == null) return null;

    try {
      final transactionId = match.group(1)!;
      final amount = double.parse(match.group(2)!.replaceAll(',', ''));
      final counterparty = match.group(3)!;
      final dateStr = match.group(4)!;
      final timeStr = match.group(5)!.trim();
      final balanceStr = match.group(6);
      final balance = balanceStr != null ? double.tryParse(balanceStr.replaceAll(',', '')) : null;

      // Extract phone number if present
      final phoneMatch = RegExp(r'(\d{10,12})').firstMatch(counterparty);
      String? phoneNumber = phoneMatch?.group(1);
      String cleanCounterparty = counterparty.replaceAll(RegExp(r'\d{10,12}'), '').trim();

      // Try 2-digit year first, fall back to 4-digit
      DateTime timestamp;
      try {
        timestamp = DateFormat('d/M/yy h:mm a').parse('$dateStr $timeStr');
      } catch (_) {
        timestamp = DateFormat('d/M/yyyy h:mm a').parse('$dateStr $timeStr');
      }

      return ParseResult(
        success: true,
        confidence: 1.0,
        parserVersion: version,
        data: Transaction(
          transactionId: transactionId,
          type: transactionType,
          amount: amount,
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
