# ParsePesa Python SDK

Official Python client for the [ParsePesa](https://parsepesa.nexoracreatives.co.ke) API. Convert raw M-Pesa SMS notifications into structured JSON data instantly and manage your webhooks.

## Installation

```bash
pip install parsepesa
```

## Quick Start

```python
from parsepesa import ParsePesa

client = ParsePesa("your_api_key_here")

# 1. Parse a message
result = client.parse("Confirmed. Ksh500.00 sent to...")

# 2. Manage Parsing Callbacks
# Set where you want the JSON result sent after every parse
client.parsing_webhooks.create("https://api.yoursite.com/parse-callback")

# 3. Manage Daraja Proxy (Safaricom Webhooks)
# Bridge Safaricom directly to your backend
client.daraja_proxy.create(
    name="Payment Bridge",
    url="https://api.yoursite.com/mpesa-bridge"
)

# 4. Check Balance
print(client.get_balance())
```

## Features
- **Unified Webhooks**: Manage both Daraja Proxy and Parsing Callback webhooks.
- **Full Account Access**: Check balances and stats via code.
- **Standardized Results**: Structured JSON for all M-Pesa formats.

## Documentation
For full API documentation, visit [parsepesa.nexoracreatives.co.ke/docs](https://parsepesa.nexoracreatives.co.ke/docs).

---
© 2026 Nexora Creative Solutions
