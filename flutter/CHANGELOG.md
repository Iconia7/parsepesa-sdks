## 2.0.1

- Enhanced reliability for Withdrawal patterns (`Confirmed.on` support).
- Added support for Card Transactions (Loop Card and M-Pesa Global Pay).
- Improved Airtime parsing to distinguish between self-purchase, purchase for others, and received airtime.
- Added support for Loan Requests (Okoa Jahazi) and Balance Information messages.
- Updated Transaction model to include `status` and `fee` fields.
- Fixed masked phone number extraction (e.g., `0710***494`).

## 2.0.0

- Fixed parsing results.
- Support for single and batch parsing.
- HMAC-ready for future Daraja Proxy integrations.
