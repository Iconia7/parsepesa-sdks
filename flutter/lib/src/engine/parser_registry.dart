import '../models/parse_result.dart';
import 'rule_based_parser.dart';
import '../rules/send_money_rule.dart';
import '../rules/till_payment_rule.dart';
import '../rules/paybill_rule.dart';
import '../rules/withdrawal_rule.dart';
import '../rules/airtime_rule.dart';
import '../rules/incoming_money_rule.dart';
import '../rules/merchant_transfer_rule.dart';
import '../rules/bank_to_mpesa_rule.dart';
import '../rules/okoa_rule.dart';
import '../rules/balance_rule.dart';
import '../rules/card_transaction_rule.dart';

class ParserRegistry {
  final List<ParseRule> _rules = [
    SendMoneyRule(),
    TillPaymentRule(),
    PaybillRule(),
    WithdrawalRule(),
    AirtimeRule(),
    IncomingMoneyRule(),
    MerchantTransferRule(),
    BankToMpesaRule(),
    OkoaRule(),
    BalanceRule(),
    CardTransactionRule(),
  ];

  ParserRegistry() {
    // Sort rules by priority (highest first)
    _rules.sort((a, b) => b.priority.compareTo(a.priority));
  }

  ParseResult parse(String rawSms, {String? senderId}) {
    for (var rule in _rules) {
      final result = rule.tryParse(rawSms, senderId);
      if (result != null && result.success) {
        return result;
      }
    }

    // If no deterministic rule matches, we will later add AI fallback here
    return ParseResult(
      success: false,
      confidence: 0.0,
      parserVersion: 'engine-1.0',
    );
  }
}
