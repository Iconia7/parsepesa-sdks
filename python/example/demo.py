from parsepesa import ParsePesa
import json

# Replace with your actual API key
API_KEY = "pp_live_your_key_here"

def main():
    print("--- ParsePesa Python Full Demo ---")
    client = ParsePesa(API_KEY)

    try:
        # 1. Check Balance
        print("\n[1] Checking account balance...")
        balance_info = client.get_balance()
        print(f"Balance: {balance_info.get('balance', 0)} KES")

        # 2. Parse an SMS
        print("\n[2] Parsing a sample M-Pesa SMS...")
        raw_sms = "Confirmed. Ksh2,500.00 paid to SHELL on 12/05/26 at 10:20 AM. ID: SLK9876QWE."
        result = client.parse(raw_sms)
        print(f"Single Parse Amount: {result['data']['amount']}")

        # 3. Batch Parsing
        print("\n[3] Batch Parsing multiple messages...")
        messages = [
            "Confirmed. Ksh100.00 sent to AGENT on 10/05/26 at 8:00 AM. ID: AAA111.",
            "Confirmed. Ksh50.00 paid to ZUKU on 11/05/26 at 9:00 PM. ID: BBB222."
        ]
        batch_result = client.batch_parse(messages)
        print(f"Successfully processed {len(batch_result.get('results', []))} messages.")

        # 4. Manage Webhooks
        print("\n[4] Setting up Webhooks...")
        
        # A. Parsing Webhook
        print("-> Configuring Parsing Callback...")
        client.parsing_webhooks.create("https://api.site.com/v1/results")

        # B. Daraja Proxy
        print("-> Configuring Daraja Proxy Bridge...")
        client.daraja_proxy.create(url="https://api.site.com/v1/bridge", name="Shop Bridge")

        webhooks = client.parsing_webhooks.list()
        print(f"Total Callbacks Configured: {len(webhooks)}")

        print("\n--- Demo Completed Successfully ---")

    except Exception as e:
        print(f"\nAn error occurred: {e}")

if __name__ == "__main__":
    main()
