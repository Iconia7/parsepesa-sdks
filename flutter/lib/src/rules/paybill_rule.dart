import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class PaybillRule implements ParseRule {
  @override
  String get transactionType => 'paybill_payment';

  @override
  String get version => '1.2.0';

  @override
  double get priority => 1.2;

  // Pattern: [ID] Confirmed. Ksh[Amount] [sent to|paid to] [Name] for account [Acc] on [Date] at [Time] [AM/PM] ...
  // Balance is optional — some abbreviated M-Pesa notifications omit it.
  static final RegExp _pattern = RegExp(
    r'([A-Z0-9]{8,12})\s+Confirmed\.\s+Ksh([\d,]+\.?\d*)\s+(?:paid|sent)\s+to\s+(.+?)\s+for\s+account\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.?(?:\s+(?:New\s+M-PESA\s+balance\s+is\s+Ksh|Merchant\s+Account\s+Balance\s+is\s+Ksh)([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    final match = _pattern.firstMatch(rawSms);
    if (match == null) return null;

    try {
      final transactionId = match.group(1)!;
      final amount = double.parse(match.group(2)!.replaceAll(',', ''));
      final paybillName = match.group(3)!;
      final accountNumber = match.group(4)!.trim();
      final dateStr = match.group(5)!;
      final timeStr = match.group(6)!.trim();
      final balanceStr = match.group(7);
      final balance = balanceStr != null ? double.tryParse(balanceStr.replaceAll(',', '')) : null;

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
          counterparty: paybillName,
          accountNumber: accountNumber,
          balance: balance,
          timestamp: timestamp,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
