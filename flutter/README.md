# ParsePesa Flutter SDK

Official Flutter client for the [ParsePesa](https://parsepesa.nexoracreatives.co.ke) API. Convert raw M-Pesa SMS notifications into structured JSON data instantly and manage your webhooks.

## Installation

```yaml
dependencies:
  parsepesa: ^1.1.0
```

## Quick Start

```dart
import 'package:parsepesa/parsepesa.dart';

void main() async {
  final client = ParsePesa("your_api_key_here");

  // 1. Manage Parsing Callbacks
  await client.parsingWebhooks.create("https://api.myapp.com/callback");

  // 2. Manage Daraja Bridges
  await client.darajaProxy.create("https://api.myapp.com/mpesa", name: "App Bridge");

  // 3. Parse and check balance
  final result = await client.parse("...");
  final info = await client.getBalance();
}
```

## Features
- **Unified Webhooks**: Control Parsing and Daraja webhooks from your app.
- **Cross-Platform**: Full support for Mobile, Web, and Desktop.
- **Billing Access**: Real-time balance monitoring.

## Documentation
For full API documentation, visit [parsepesa.nexoracreatives.co.ke/docs](https://parsepesa.nexoracreatives.co.ke/docs).

---
© 2026 Nexora Creative Solutions
