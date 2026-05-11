# ParsePesa PHP SDK 🐘

The official PHP SDK for **ParsePesa** - The Stripe for M-Pesa SMS. Convert raw M-Pesa messages into structured JSON in milliseconds.

## Installation

Install the package via [Composer](https://getcomposer.org/):

```bash
composer require parsepesa/php
```

## Quick Start

```php
use ParsePesa\ParsePesa;

$sdk = new ParsePesa('your_api_key');

// Parse a single message
$result = $sdk->parse("Confirmed. You have received KES 500.00 from JOHN DOE...");

echo $result['amount']; // 500
echo $result['counterparty']; // JOHN DOE
```

## Features

### 1. Single Parsing
```php
$result = $sdk->parse($message);
```

### 2. Batch Parsing
```php
$results = $sdk->batchParse([$msg1, $msg2]);
```

### 3. Account Balance
```php
$balance = $sdk->getBalance();
echo "KES " . $balance;
```

### 4. Handling Webhooks
Use this in your callback URL endpoint:
```php
$data = $sdk->handleWebhook();
// Process $data['type'], $data['amount'], etc.
```

## Requirements
- PHP 7.4 or higher
- `guzzlehttp/guzzle` 7.0+

## License
MIT
