import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class BankToMpesaRule implements ParseRule {
  @override
  String get transactionType => 'bank_to_mpesa';

  @override
  String get version => '1.1.0';

  @override
  double get priority => 1.4;

  // KCB Pattern
  static final RegExp _kcbPattern = RegExp(
    r'Ksh\s+([\d,]+\.\d{2})\s+sent\s+to\s+KCB\s+account\s+(.+?)\s+(\d+)\s+has\s+been\s+received\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}\s+[AP]M)\.\s+M-PESA\s+Ref\s+([A-Z0-9]{10})',
    caseSensitive: false,
  );

  // CoopBank Pattern
  static final RegExp _coopPattern = RegExp(
    r'you\s+have\s+sent\s+Ksh\.\s+([\d,]+\.?\d*)\s+to\s+(.+?)\s+for\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?)\.\s+MPESA\s+Ref\.\s+([A-Z0-9]{10})',
    caseSensitive: false,
  );

  // Equity Pattern (Deposited/Sent)
  static final RegExp _equityPattern = RegExp(
    r'(?:KES\.|KShs\.)\s*([\d,]+\.?\d*)\s+(?:has\s+successfully\s+been\s+deposited\s+to|sent\s+to\s+your\s+MPESA)\.?\s*(?:Equity\s+Account\s+in\s+favor\s+of\s+)?(.+?)\s+(?:Ref\.\s+Number|receipt\s+number\s+is)\s+([A-Z0-9]{10})\s+on\s+(\d{1,2}-\d{1,2}-\d{4})\s+at\s+(\d{1,2}:\d{2})',
    caseSensitive: false,
  );

  // Absa Pattern
  static final RegExp _absaPattern = RegExp(
    r'You\s+have\s+deposited\s+KES([\d,]+\.?\d*)\s+MPESA\s+ref:\s+([A-Z0-9]{10})\s+to\s+account\s+(.+?)\s+for\s+(.+?)\s+through\s+Absa\s+Bank',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    // Try each pattern...
    final kcbMatch = _kcbPattern.firstMatch(rawSms);
    if (kcbMatch != null) return _buildResult(kcbMatch.group(6)!, kcbMatch.group(1)!, kcbMatch.group(2)!, kcbMatch.group(4)!, kcbMatch.group(5)!);

    final coopMatch = _coopPattern.firstMatch(rawSms);
    if (coopMatch != null) return _buildResult(coopMatch.group(6)!, coopMatch.group(1)!, coopMatch.group(2)!, coopMatch.group(4)!, coopMatch.group(5)!);

    final equityMatch = _equityPattern.firstMatch(rawSms);
    if (equityMatch != null) return _buildResult(equityMatch.group(3)!, equityMatch.group(1)!, equityMatch.group(2)!, equityMatch.group(4)!, equityMatch.group(5)!);

    final absaMatch = _absaPattern.firstMatch(rawSms);
    if (absaMatch != null) return _buildResult(absaMatch.group(2)!, absaMatch.group(1)!, absaMatch.group(4)!, DateTime.now().toString(), "");

    return null;
  }

  ParseResult _buildResult(String ref, String amt, String counter, String date, String time) {
    DateTime? timestamp;
    try {
      timestamp = DateFormat('dd/MM/yyyy h:mm a').parse('$date $time');
    } catch (_) {
      try {
        timestamp = DateFormat('dd-MM-yyyy HH:mm').parse('$date $time');
      } catch (_) {
        timestamp = DateTime.now();
      }
    }

    final phoneMatch = RegExp(r'(\d{10,12})').firstMatch(counter);
    String? phoneNumber = phoneMatch?.group(1);
    String cleanCounterparty = counter.replaceAll(RegExp(r'\d{10,12}'), '').trim();

    return ParseResult(
      success: true,
      confidence: 0.95,
      parserVersion: version,
      data: Transaction(
        transactionId: ref,
        type: transactionType,
        amount: double.parse(amt.replaceAll(',', '')),
        currency: 'KES',
        counterparty: cleanCounterparty.isEmpty ? counter.trim() : cleanCounterparty,
        phoneNumber: phoneNumber,
        timestamp: timestamp,
      ),
    );
  }
}
