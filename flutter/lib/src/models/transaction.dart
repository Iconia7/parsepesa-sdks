class Transaction {
  final String transactionId;
  final String type;
  final double amount;
  final String currency;
  final String counterparty;
  final String? phoneNumber;
  final String? accountNumber;
  final double? balance;
  final DateTime timestamp;

  Transaction({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.counterparty,
    this.phoneNumber,
    this.accountNumber,
    this.balance,
    required this.timestamp,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Defensively parse timestamp — AI may return various formats
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      timestamp = DateTime.now();
    }

    return Transaction(
      transactionId: (json['transactionId'] ?? json['transaction_id'] ?? 'AI${DateTime.now().millisecondsSinceEpoch}').toString(),
      type: (json['type'] ?? 'unknown').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'KES',
      counterparty: (json['counterparty'] ?? json['recipient'] ?? 'Unknown').toString(),
      phoneNumber: json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      accountNumber: json['accountNumber'] as String? ?? json['account_number'] as String?,
      balance: json['balance'] != null ? (json['balance'] as num).toDouble() : null,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'counterparty': counterparty,
      'phoneNumber': phoneNumber,
      'accountNumber': accountNumber,
      'balance': balance,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
