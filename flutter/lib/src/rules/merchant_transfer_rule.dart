import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class MerchantTransferRule implements ParseRule {
  @override
  String get transactionType => 'merchant_transfer';

  @override
  String get version => '1.0.0';

  @override
  double get priority => 1.3;

  // Pattern: [ID] Confirmed. Ksh[Amount] transferred to [Name] [Date] at [Time] [AM/PM]. Merchant Account Balance is Ksh[Balance]
  static final RegExp _pattern = RegExp(
    r'([A-Z0-9]{8,12})\s+Confirmed\.\s+Ksh([\d,]+\.\d{2})\s+transferred\s+to\s+(.+?)\s+(\d{1,2}/\d{1,2}/\d{2})\s+at\s+(\d{1,2}:\d{2}\s+[AP]M)\.?\s*Merchant\s+Account\s+Balance\s+is\s+Ksh([\d,]+\.\d{2})',
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
      final timeStr = match.group(5)!;
      final balance = double.parse(match.group(6)!.replaceAll(',', ''));

      final dateFormat = DateFormat('d/M/yy h:mm a');
      final timestamp = dateFormat.parse('$dateStr $timeStr');

      return ParseResult(
        success: true,
        confidence: 1.0,
        parserVersion: version,
        data: Transaction(
          transactionId: transactionId,
          type: transactionType,
          amount: amount,
          currency: 'KES',
          counterparty: counterparty,
          balance: balance,
          timestamp: timestamp,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
