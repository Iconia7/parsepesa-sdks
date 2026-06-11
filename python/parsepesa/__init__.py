import requests
import uuid as _uuid_mod

class ParsePesaError(Exception):
    """Raised when the ParsePesa API returns an error response."""
    def __init__(self, message, status_code=None, code=None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code  # e.g. "BALANCE_RACE"


class ParseResult:
    """Wraps a parse API response with helper properties."""
    def __init__(self, data: dict, headers: dict = None):
        self._data = data
        self._headers = headers or {}

    @property
    def success(self) -> bool:
        return self._data.get("success", False)

    @property
    def confidence(self) -> float:
        return self._data.get("confidence", 0.0)

    @property
    def transaction(self) -> dict:
        return self._data.get("data") or {}

    @property
    def is_replay(self) -> bool:
        """True if this response was served from the idempotency cache."""
        return self._headers.get("x-idempotent-replay", "").lower() == "true"

    @property
    def idempotency_stored(self) -> bool:
        """
        False if the idempotency record could not be persisted after billing.
        If False, do NOT retry with the same idempotency key.
        """
        return self._headers.get("x-idempotency-stored", "true").lower() != "false"

    @property
    def request_id(self) -> str:
        return self._headers.get("x-request-id", "")

    def to_dict(self) -> dict:
        return self._data


class ParsePesa:
    """
    ParsePesa Python SDK — v2.0.0

    Changelog v2.0:
      - parse() now accepts idempotency_key to prevent double billing on retries
      - ParseResult exposes .is_replay and .idempotency_stored for safe retry logic
      - rotate_key() — zero-downtime API key rotation with 24h grace period
      - webhook.deliveries() — view delivery history for a webhook
      - Correct batch endpoint (/parse/batch not /batch-parse)
      - Raises ParsePesaError on non-2xx instead of returning raw error dicts
    """

    SDK_VERSION = "2.0.0"

    def __init__(self, api_key, base_url="https://api.parsepesa.nexoracreatives.co.ke/v1"):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "X-SDK-Platform": "Python",
            "X-SDK-Version": self.SDK_VERSION,
        })
        self.webhooks = WebhooksManager(self, "/user/webhooks")
        self.daraja_proxy = WebhooksManager(self, "/user/daraja-proxy")

    def _request(self, method, path, **kwargs):
        url = f"{self.base_url}{path}"
        response = self.session.request(method, url, **kwargs)
        if not response.ok:
            data = {}
            try:
                data = response.json()
            except Exception:
                pass
            raise ParsePesaError(
                data.get("error", f"Request failed: {response.status_code}"),
                status_code=response.status_code,
                code=data.get("code"),
            )
        return response

    def parse(self, raw_text: str, idempotency_key: str = None) -> "ParseResult":
        """
        Parse a single M-Pesa SMS message.

        Args:
            raw_text: The raw SMS string.
            idempotency_key: A unique key (max 128 chars) to prevent double billing
                             on retries. If omitted, no deduplication is applied.
                             Use a stable ID tied to the SMS (e.g. a message hash).

        Returns:
            ParseResult with .success, .confidence, .transaction, .is_replay

        Raises:
            ParsePesaError: On non-2xx responses (including 402 insufficient balance).
        """
        headers = {}
        if idempotency_key:
            headers["X-Idempotency-Key"] = str(idempotency_key)

        response = self._request(
            "POST", "/parse",
            json={"raw_text": raw_text},
            headers=headers,
        )
        return ParseResult(response.json(), dict(response.headers))

    def parse_safe(self, raw_text: str, idempotency_key: str = None) -> "ParseResult":
        """
        Like parse(), but auto-generates an idempotency key from the SMS text
        if none is provided. Safe to call multiple times for the same SMS.
        """
        if idempotency_key is None:
            import hashlib
            idempotency_key = hashlib.sha256(raw_text.encode()).hexdigest()[:32]
        return self.parse(raw_text, idempotency_key=idempotency_key)

    def batch_parse(self, raw_texts: list) -> list:
        """
        Parse up to 100 SMS messages in one request.
        Note: batch parse does not support idempotency keys.
        """
        if len(raw_texts) > 100:
            raise ValueError("Batch limit is 100 items")
        response = self._request(
            "POST", "/parse/batch",  # correct endpoint
            json=[{"raw_text": t} for t in raw_texts],
        )
        return response.json()

    def get_balance(self) -> float:
        """Returns current account balance in KES."""
        response = self._request("GET", "/user/stats")
        return float(response.json().get("balance", 0.0))

    def list_keys(self) -> list:
        """List all API keys on this account."""
        return self._request("GET", "/user/keys").json()

    def rotate_key(self, key_id: str) -> dict:
        """
        Rotate an API key with zero downtime.
        The old key remains valid for 24 hours (grace period).

        Returns:
            dict with 'apiKey' (new key), 'graceExpiresAt', and 'message'.
        """
        return self._request("POST", f"/user/keys/{key_id}/rotate").json()

    def get_stats(self) -> dict:
        """Returns account stats: totalParses, successRate, avgLatency, etc."""
        return self._request("GET", "/user/stats").json()


class WebhooksManager:
    """Manages webhook registrations and delivery history."""

    def __init__(self, client: ParsePesa, path: str):
        self._client = client
        self._path = path

    def list(self) -> list:
        return self._client._request("GET", self._path).json()

    def create(self, url: str, name: str = None, auto_validate: bool = True) -> dict:
        return self._client._request(
            "POST", self._path,
            json={"url": url, "destinationUrl": url, "name": name, "autoValidate": auto_validate},
        ).json()

    def delete(self, webhook_id: str) -> bool:
        self._client._request("DELETE", f"{self._path}/{webhook_id}")
        return True

    def deliveries(self, webhook_id: str) -> list:
        """
        Get the last 50 delivery attempts for a webhook.
        Each entry includes: status, attemptCount, lastResponseCode,
        deliveredAt, nextAttemptAt, lastError.

        Use this to debug failed webhooks or confirm delivery.
        """
        return self._client._request(
            "GET", f"{self._path}/{webhook_id}/deliveries"
        ).json()

    @staticmethod
    def verify_signature(payload: bytes, signature: str, secret: str) -> bool:
        """
        Verify an incoming webhook's HMAC-SHA256 signature.
        Call this in your webhook endpoint before processing the event.

        Args:
            payload: Raw request body bytes.
            signature: Value of the X-ParsePesa-Signature header.
            secret: The webhook secret from createWebhook() response.

        Returns:
            True if signature is valid.
        """
        import hmac
        import hashlib
        expected = hmac.new(
            secret.encode(), payload, hashlib.sha256
        ).hexdigest()
        return hmac.compare_digest(expected, signature)
