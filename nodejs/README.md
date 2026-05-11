# ParsePesa Node.js SDK

Official Node.js client for the [ParsePesa](https://parsepesa.nexoracreatives.co.ke) API. Convert raw M-Pesa SMS notifications into structured JSON data instantly and manage your webhooks.

## Installation

```bash
npm install parsepesa
```

## Quick Start

```javascript
const ParsePesa = require('parsepesa');
const client = new ParsePesa("your_api_key_here");

async function main() {
  // 1. Set a parsing callback
  await client.parsingWebhooks.create("https://api.site.com/callback");

  // 2. Set a Daraja Proxy bridge
  await client.darajaProxy.create("https://api.site.com/mpesa", "Prod Bridge");

  // 3. Check balance
  const info = await client.getBalance();
  console.log(info.balance);
}
main();
```

## Features
- **Unified Webhooks**: Full control over Parsing and Daraja webhooks.
- **TypeScript Ready**: Complete type definitions included.
- **Zero Dependencies**: Lightweight and secure.

## Documentation
For full API documentation, visit [parsepesa.nexoracreatives.co.ke/docs](https://parsepesa.nexoracreatives.co.ke/docs).

---
© 2026 Nexora Creative Solutions
