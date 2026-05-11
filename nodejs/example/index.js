const ParsePesa = require('../index');

// Replace with your actual API key from the ParsePesa dashboard
const API_KEY = 'pp_live_your_key_here';

const client = new ParsePesa(API_KEY);

async function runDemo() {
  console.log('--- ParsePesa Node.js Full Demo ---');

  try {
    // 1. Check Balance
    console.log('\n[1] Checking balance...');
    const balanceInfo = await client.getBalance();
    console.log(`Current Balance: ${balanceInfo.balance} KES`);

    // 2. Parse a single message
    console.log('\n[2] Parsing a single M-Pesa SMS...');
    const rawSms = "Confirmed. Ksh1,200.00 sent to JANE DOE on 12/05/26 at 4:15 PM. ID: RKL1234ABC.";
    const result = await client.parse(rawSms);
    console.log('Single Parse Amount:', result.data.amount);

    // 3. Batch Parse (Multiple messages at once)
    console.log('\n[3] Batch Parsing multiple messages...');
    const messages = [
      "Confirmed. Ksh500.00 paid to KPLC on 10/05/26 at 9:00 AM. ID: PQR112233.",
      "Confirmed. Ksh200.00 sent to JOHN SMITH on 11/05/26 at 2:30 PM. ID: XYZ445566."
    ];
    const batchResult = await client.batchParse(messages);
    console.log(`Batch processed ${batchResult.results.length} messages.`);

    // 4. Manage Webhooks
    console.log('\n[4] Setting up Webhooks...');
    
    // A. Parsing Webhook: JSON result delivery
    console.log('-> Configuring Parsing Callback...');
    await client.parsingWebhooks.create("https://api.site.com/v1/parse-results");

    // B. Daraja Proxy: Safaricom bridge
    console.log('-> Configuring Daraja Proxy Bridge...');
    await client.darajaProxy.create("https://api.site.com/v1/mpesa-bridge", "Main Bridge");

    const bridges = await client.darajaProxy.list();
    console.log(`Total active bridges: ${bridges.length}`);

    console.log('\n--- Demo Completed Successfully ---');

  } catch (error) {
    console.error('\nERROR:', error.message);
  }
}

runDemo();
