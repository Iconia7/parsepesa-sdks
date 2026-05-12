# ParsePesa Flutter SDK

Official Flutter SDK for [ParsePesa](https://parsepesa.nexoracreatives.co.ke). The ultimate toolkit for M-Pesa integration.

## 🚀 The Hybrid Strategy
ParsePesa now works **offline and for free** by default. Use the local parsing engine for privacy and speed, and connect to our Cloud API for advanced AI fallbacks and dashboards.

## Installation

```yaml
dependencies:
  parsepesa: ^2.0.0
```

## Quick Start

### 1. Free Offline Mode (No API Key Required)
Parse SMS instantly on the device without any network calls.

```dart
import 'package:parsepesa/parsepesa.dart';

final result = ParsePesa().parseLocal("Confirmed. You have received KES 500...");
print(result.data?.amount); // 500.0
```

### 2. Hybrid Cloud Mode (Paid API Key)
Activate "Cloud Mode" to get **AI Smart Fallbacks** for complex messages and automatic syncing to your **ParsePesa Dashboard**.

```dart
import 'package:parsepesa/parsepesa.dart';

void main() {
  // Initialize once
  ParsePesa.init(
    apiKey: "pp_live_...", 
    syncToCloud: true, // Auto-sync local parses to your dashboard
  );
}

// Later in your code...
final result = await ParsePesa.instance.parse("..."); 
```

## Features
- **🆓 100% Free Local Parsing**: High-performance regex rules that run on the device.
- **🧠 AI Smart Fallback**: If local rules fail, our Cloud AI (Gemini) takes over.
- **☁️ Automatic Sync**: Mirror your app's transactions to the Cloud Dashboard for accounting and webhooks.
- **🛡️ Privacy First**: Financial data stays on the device unless you choose to sync it.

## Documentation
For full API documentation, visit [parsepesa.nexoracreatives.co.ke/docs](https://parsepesa.nexoracreatives.co.ke/docs).

---
© 2026 Nexora Creative Solutions
