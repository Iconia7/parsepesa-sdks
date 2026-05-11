<?php

require 'vendor/autoload.php';

use ParsePesa\ParsePesa;

/**
 * --- 1. INITIALIZATION ---
 */
$sdk = new ParsePesa('your_api_key_here');

try {
    /**
     * --- 2. CHECK BALANCE ---
     */
    $balance = $sdk->getBalance();
    echo "Current Balance: KES " . $balance . PHP_EOL;

    /**
     * --- 3. SINGLE PARSE ---
     */
    echo "Parsing single message..." . PHP_EOL;
    $message = "Confirmed. You have received KES 1,500.00 from JOHN DOE 0712345678 on 12/5/26 at 10:30 AM. New M-PESA balance is KES 5,400.00.";
    $result = $sdk->parse($message);
    echo "Transaction Type: " . $result['type'] . PHP_EOL;
    echo "Amount: " . $result['amount'] . PHP_EOL;

    /**
     * --- 4. BATCH PARSE ---
     */
    echo "Parsing batch..." . PHP_EOL;
    $messages = [
        "LQK21TR456 Confirmed. You have received KES 500.00 from JANE DOE.",
        "MHT52RT789 Confirmed. KES 200.00 paid to KPLC."
    ];
    $batchResults = $sdk->batchParse($messages);
    echo "Batch processed " . count($batchResults) . " messages." . PHP_EOL;

    /**
     * --- 5. MANAGEMENT (WEBHOOKS) ---
     */
    echo PHP_EOL . "--- MANAGEMENT EXAMPLE ---" . PHP_EOL;

    // List Webhooks
    $webhooks = $sdk->listWebhooks();
    echo "You have " . count($webhooks) . " active webhooks." . PHP_EOL;

    // Create a new Webhook
    // $newWebhook = $sdk->createWebhook('https://your-site.com/callback', 'Production Server');

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . PHP_EOL;
}

/**
 * --- 6. WEBHOOK HANDLING (CALLBACKS) ---
 * Place this code in your 'callback.php' or endpoint file.
 */
echo PHP_EOL . "--- WEBHOOK HANDLING EXAMPLE ---" . PHP_EOL;
echo "// 1. Capture and decode the incoming webhook from ParsePesa" . PHP_EOL;
$data = $sdk->handleWebhook();

if (!empty($data)) {
    echo "Received Webhook: " . ($data['type'] ?? 'Unknown') . PHP_EOL;
    
    // Example logic
    if (isset($data['type']) && $data['type'] === 'send_money') {
        $amount = $data['amount'];
        $sender = $data['counterparty'];
        echo "LOGIC: Payment of $amount received from $sender. Updating order status..." . PHP_EOL;
    }
} else {
    echo "// Note: handleWebhook() will be empty in this CLI demo because no POST data was sent." . PHP_EOL;
}
