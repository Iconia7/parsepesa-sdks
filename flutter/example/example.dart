import 'package:parsepesa/parsepesa.dart';

void main() async {
  print('--- ParsePesa Flutter Hybrid Demo ---');

  // --- MODE 1: 100% FREE & OFFLINE ---
  print('\n[1] Running in FREE OFFLINE Mode...');
  // No initialization or API key needed for local parsing
  const rawSms = "Confirmed. Ksh300.00 sent to M-PESA AGENT on 12/05/26 at 11:45 AM. ID: AGT7766XYZ.";
  
  // Use parseLocal for guaranteed zero network calls
  final localResult = ParsePesa().parseLocal(rawSms);
  
  if (localResult.success) {
    print('✅ Local Parse Success!');
    print('   Transaction ID: ${localResult.data?.transactionId}');
    print('   Amount: ${localResult.data?.amount} ${localResult.data?.currency}');
    print('   Type: ${localResult.data?.type}');
  }

  // --- MODE 2: HYBRID CLOUD MODE (PAID) ---
  print('\n[2] Initializing HYBRID CLOUD Mode...');
  
  // Initialize with your API key to unlock Cloud Sync and AI Fallbacks
  ParsePesa.init(
    apiKey: 'pp_live_your_key_here',
    syncToCloud: true, // Automatically sync local parses to your dashboard
  );

  final client = ParsePesa.instance;

  try {
    // A. Check Balance (Cloud Only)
    print('-> Fetching cloud balance...');
    final balanceInfo = await client.getBalance();
    if (balanceInfo['success'] == true) {
      print('   Current Balance: ${balanceInfo['balance']} KES');
    }

    // B. Smart Parse (Tries local first, syncs to cloud in background)
    print('-> Running Smart Parse (Local + Sync)...');
    final result = await client.parse(rawSms);
    print('   Parse Result Source: ${result['parserVersion']}');

    // C. AI Fallback (If local rules fail, it calls Cloud AI automatically)
    print('-> Testing AI Fallback (with complex text)...');
    const complexSms = "You have received KES 1,200.00 from John Doe. New balance is KES 5,000.00.";
    final aiResult = await client.parse(complexSms);
    print('   AI Parse Success: ${aiResult['success']}');
    print('   Extracted Counterparty: ${aiResult['data']?['counterparty']}');

    // D. Batch Parsing (Cloud Only)
    print('-> Batch Parsing multiple messages...');
    final batchResult = await client.batchParse([
      "Confirmed. Ksh1,000.00 paid to NAIROBI WATER on 10/05/26 at 2:00 PM. ID: WTR1122.",
      "Confirmed. Ksh500.00 sent to MOM on 11/05/26 at 6:30 PM. ID: MOM3344."
    ]);
    print('   Batch processed ${batchResult['results']?.length ?? 0} messages.');

    // E. Webhook & Bridge Management (Cloud Only)
    print('-> Configuring cloud webhooks & Daraja bridges...');
    
    // Parsing Webhook
    await client.parsingWebhooks.create("https://api.myapp.com/callback");

    // Daraja Proxy Bridge
    await client.darajaProxy.create("https://api.myapp.com/mpesa-bridge", name: "Main Bridge");
    final bridges = await client.darajaProxy.list();
    print('   Total active Daraja bridges: ${bridges.length}');
    
    print('\n--- Demo Completed Successfully ---');

  } catch (e) {
    print('\n⚠️ Cloud features failed (likely invalid API key): $e');
  }
}
