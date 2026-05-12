import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class IncomingMoneyRule implements ParseRule {
  @override
  String get transactionType => 'incoming_money';

  @override
  String get version => '1.2.0';

  @override
  double get priority => 1.5;

  // Pattern 1: [ID] Confirmed.on [Date] at [Time][AM/PM]Ksh[Amount] received from [Name]. New Account balance is Ksh[Balance].
  static final RegExp _pattern1 = RegExp(
    r'([A-Z0-9]{8,12})\s+Confirmed\.on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2})\s+([AP]M)Ksh([\d,]+\.?\d*)\s+received\s+from\s+(.+?)\.\s+New\s+Account\s+balance\s+is\s+Ksh([\d,]+\.?\d*)\.',
    caseSensitive: false,
  );

  // Pattern 2: Congratulations! [ID] confirmed. You have received Ksh[Amount] from [Name] on [Date] at [Time] [AM/PM]. New M-PESA balance is Ksh[Balance]
  static final RegExp _pattern2 = RegExp(
    r'(?:Congratulations!\s+)?([A-Z0-9]{8,12})\s+confirmed\.?\s*(?:You\s+have\s+received|received)\s+Ksh([\d,]+\.?\d*)\s+from\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2})\s+([AP]M)\.?\s*(?:New\s+M-PESA\s+balance\s+is\s+Ksh([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  // Pattern 3: "You have received Ksh[Amount] from [Name] on [Date] at [Time] [AM/PM]." — no transaction ID
  static final RegExp _pattern3 = RegExp(
    r'You\s+have\s+received\s+Ksh([\d,]+\.?\d*)\s+from\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.?',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    // Try Pattern 1
    var match = _pattern1.firstMatch(rawSms);
    if (match != null) {
      return _buildResult(
        id: match.group(1)!,
        date: match.group(2)!,
        time: '${match.group(3)!} ${match.group(4)!}',
        amount: match.group(5)!,
        counterparty: match.group(6)!,
        balance: match.group(7),
      );
    }

    // Try Pattern 2
    match = _pattern2.firstMatch(rawSms);
    if (match != null) {
      return _buildResult(
        id: match.group(1)!,
        amount: match.group(2)!,
        counterparty: match.group(3)!,
        date: match.group(4)!,
        time: '${match.group(5)!} ${match.group(6)!}',
        balance: match.group(7),
      );
    }

    // Try Pattern 3 (no transaction ID)
    match = _pattern3.firstMatch(rawSms);
    if (match != null) {
      return _buildResult(
        id: 'IN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        amount: match.group(1)!,
        counterparty: match.group(2)!,
        date: match.group(3)!,
        time: match.group(4)!,
        balance: null,
      );
    }

    return null;
  }

  ParseResult? _buildResult({
    required String id,
    required String date,
    required String time,
    required String amount,
    required String counterparty,
    String? balance,
  }) {
    try {
      DateTime timestamp;
      try {
        timestamp = DateFormat('d/M/yy h:mm a').parse('$date ${time.trim()}');
      } catch (_) {
        timestamp = DateFormat('d/M/yyyy h:mm a').parse('$date ${time.trim()}');
      }

      // Extract phone number if present (including masked numbers like 0710***494)
      final phoneMatch = RegExp(r'(\d{3,4}[\*x]+\d{3,4}|\d{10,12})').firstMatch(counterparty);
      String? phoneNumber = phoneMatch?.group(1);
      String cleanCounterparty = counterparty.replaceAll(RegExp(r'\d{3,4}[\*x]+\d{3,4}|\d{10,12}'), '').trim();

      return ParseResult(
        success: true,
        confidence: 1.0,
        parserVersion: version,
        data: Transaction(
          transactionId: id,
          type: transactionType,
          amount: double.parse(amount.replaceAll(',', '')),
          currency: 'KES',
          counterparty: (cleanCounterparty.isEmpty ? counterparty : cleanCounterparty).replaceAll(RegExp(r'\s+'), ' '),
          phoneNumber: phoneNumber,
          balance: balance != null ? double.tryParse(balance.replaceAll(',', '')) : null,
          timestamp: timestamp,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
