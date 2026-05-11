import requests

class ParsePesa:
    def __init__(self, api_key, base_url="https://api.parsepesa.nexoracreatives.co.ke/v1"):
        self.api_key = api_key
        self.base_url = base_url
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        self.daraja_proxy = WebhooksManager(self, "/user/daraja-proxy")
        self.parsing_webhooks = WebhooksManager(self, "/user/webhooks")

    def parse(self, raw_text):
        """Parse a single M-Pesa SMS message."""
        url = f"{self.base_url}/parse"
        payload = {"raw_text": raw_text}
        response = requests.post(url, json=payload, headers=self.headers)
        return response.json()

    def batch_parse(self, raw_texts):
        """Parse multiple messages in one request (up to 50)."""
        url = f"{self.base_url}/batch-parse"
        payload = {"messages": raw_texts}
        response = requests.post(url, json=payload, headers=self.headers)
        return response.json()

    def get_balance(self):
        """Check your current account balance."""
        url = f"{self.base_url}/user/stats"
        response = requests.get(url, headers=self.headers)
        if response.ok:
            data = response.json()
            return {"success": True, "balance": data.get("balance", 0)}
        return response.json()

class WebhooksManager:
    """Manages Webhook Routes and Daraja Proxy Bridges."""
    def __init__(self, client, endpoint):
        self.client = client
        self.endpoint = endpoint
        self.base_url = f"{client.base_url}{endpoint}"

    def list(self):
        """List all active webhook routes."""
        response = requests.get(self.base_url, headers=self.client.headers)
        return response.json()

    def create(self, url, name=None, auto_validate=True):
        """Create a new webhook route or bridge."""
        payload = {
            "url": url,
            "destinationUrl": url, # Compatibility for Daraja Proxy
            "name": name,
            "autoValidate": auto_validate
        }
        response = requests.post(self.base_url, json=payload, headers=self.client.headers)
        return response.json()

    def delete(self, route_id):
        """Delete a webhook route."""
        url = f"{self.base_url}/{route_id}"
        response = requests.delete(url, headers=self.client.headers)
        return response.status_code == 200 or response.status_code == 204
