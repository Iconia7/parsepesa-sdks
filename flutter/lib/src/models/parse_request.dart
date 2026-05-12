class ParseRequest {
  final String rawText;
  final String? senderId;

  ParseRequest({
    required this.rawText,
    this.senderId,
  });

  factory ParseRequest.fromJson(Map<String, dynamic> json) {
    return ParseRequest(
      rawText: json['raw_text'] as String,
      senderId: json['sender_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'raw_text': rawText,
      'sender_id': senderId,
    };
  }
}
