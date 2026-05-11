import 'package:parsepesa/parsepesa.dart';

void main() async {
  print('--- ParsePesa Flutter/Dart Full Demo ---');

  // Replace with your actual API key
  const apiKey = 'pp_live_your_key_here';
  final client = ParsePesa(apiKey);

  try {
    // 1. Check Balance
    print('\n[1] Fetching balance...');
    final balanceInfo = await client.getBalance();
    print('Current Balance: ${balanceInfo['balance']} KES');

    // 2. Parse a single message
    print('\n[2] Parsing a sample SMS...');
    const rawSms = "Confirmed. Ksh300.00 sent to M-PESA AGENT on 12/05/26 at 11:45 AM. ID: AGT7766XYZ.";
    final result = await client.parse(rawSms);
    print('Single Parse Amount: ${result['data']['amount']}');

    // 3. Batch Parsing
    print('\n[3] Batch Parsing multiple messages...');
    final batchResult = await client.batchParse([
      "Confirmed. Ksh1,000.00 paid to NAIROBI WATER on 10/05/26 at 2:00 PM. ID: WTR1122.",
      "Confirmed. Ksh500.00 sent to MOM on 11/05/26 at 6:30 PM. ID: MOM3344."
    ]);
    final results = batchResult['results'] as List;
    print('Batch processed ${results.length} messages.');

    // 4. Webhook Management
    print('\n[4] Setting up Webhooks...');
    
    // A. Parsing Webhook
    print('-> Configuring Parsing Callback...');
    await client.parsingWebhooks.create("https://api.app.com/v1/parse-data");

    // B. Daraja Proxy Bridge
    print('-> Configuring Daraja Proxy Bridge...');
    await client.darajaProxy.create("https://api.app.com/v1/bridge", name: "Main Bridge");

    final bridges = await client.darajaProxy.list();
    print('Total active bridges: ${bridges.length}');

    print('\n--- Demo Completed Successfully ---');

  } catch (e) {
    print('\nError occurred: $e');
  }
}
