<?php

namespace ParsePesa;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use GuzzleHttp\Psr7\Response;

/**
 * ParsePesa PHP SDK — v2.0.0
 *
 * Changelog v2.0:
 *   - parse() accepts $idempotencyKey to prevent double billing on retries
 *   - ParseResult DTO with isReplay(), idempotencyStored(), requestId()
 *   - rotateKey() — zero-downtime key rotation with 24h grace period
 *   - listWebhookDeliveries() — view delivery history for a webhook
 *   - Corrected batch endpoint (/parse/batch not /batch-parse)
 *   - parse() request body key is 'raw_text' not 'message'
 *   - ParsePesaException with statusCode and code properties
 *   - verifyWebhookSignature() static helper
 */

class ParsePesaException extends \RuntimeException
{
    public int $statusCode;
    public ?string $code;

    public function __construct(string $message, int $statusCode = 0, ?string $code = null)
    {
        parent::__construct($message);
        $this->statusCode = $statusCode;
        $this->code = $code; // e.g. 'BALANCE_RACE'
    }
}

class ParseResult
{
    private array $data;
    private array $headers;

    public function __construct(array $data, array $headers = [])
    {
        $this->data = $data;
        $this->headers = array_change_key_case($headers, CASE_LOWER);
    }

    public function isSuccess(): bool
    {
        return ($this->data['success'] ?? false) === true;
    }

    public function getConfidence(): float
    {
        return (float) ($this->data['confidence'] ?? 0.0);
    }

    public function getTransaction(): array
    {
        return $this->data['data'] ?? [];
    }

    /** True if served from idempotency cache — you were not charged. */
    public function isReplay(): bool
    {
        return strtolower($this->headers['x-idempotent-replay'] ?? '') === 'true';
    }

    /**
     * False if the idempotency record could not be persisted after billing.
     * If false, do NOT retry with the same key.
     */
    public function idempotencyStored(): bool
    {
        return strtolower($this->headers['x-idempotency-stored'] ?? 'true') !== 'false';
    }

    public function getRequestId(): ?string
    {
        return $this->headers['x-request-id'] ?? null;
    }

    public function toArray(): array
    {
        return $this->data;
    }
}

class ParsePesa
{
    const SDK_VERSION = '2.0.0';

    private string $apiKey;
    private string $baseUrl;
    private Client $client;

    /**
     * @param string $apiKey  Your ParsePesa API key (pp_live_...)
     * @param string $baseUrl Override for self-hosted instances
     */
    public function __construct(
        string $apiKey,
        string $baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1'
    ) {
        $this->apiKey = $apiKey;
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->client = new Client([
            'base_uri' => $this->baseUrl . '/',
            'headers' => [
                'Authorization' => 'Bearer ' . $apiKey,
                'Content-Type'  => 'application/json',
                'X-SDK-Platform' => 'PHP',
                'X-SDK-Version'  => self::SDK_VERSION,
            ],
        ]);
    }

    /** @throws ParsePesaException|GuzzleException */
    private function request(string $method, string $path, array $options = []): array
    {
        try {
            /** @var Response $response */
            $response = $this->client->request($method, ltrim($path, '/'), $options);
            $body = json_decode($response->getBody()->getContents(), true);
            $headers = [];
            foreach ($response->getHeaders() as $name => $values) {
                $headers[strtolower($name)] = implode(', ', $values);
            }
            return ['body' => $body, 'headers' => $headers, 'status' => $response->getStatusCode()];
        } catch (\GuzzleHttp\Exception\BadResponseException $e) {
            $response = $e->getResponse();
            $body = [];
            try {
                $body = json_decode($response->getBody()->getContents(), true) ?? [];
            } catch (\Exception $_) {}
            throw new ParsePesaException(
                $body['error'] ?? 'Request failed: ' . $response->getStatusCode(),
                $response->getStatusCode(),
                $body['code'] ?? null,
            );
        }
    }

    /**
     * Parse a single M-Pesa SMS message.
     *
     * @param string      $rawText        The raw SMS text.
     * @param string|null $idempotencyKey Optional key (max 128 chars) to prevent
     *                                    double billing on retries. Recommended:
     *                                    hash of the SMS text.
     * @return ParseResult
     * @throws ParsePesaException|GuzzleException
     */
    public function parse(string $rawText, ?string $idempotencyKey = null): ParseResult
    {
        $headers = [];
        if ($idempotencyKey !== null) {
            $headers['X-Idempotency-Key'] = $idempotencyKey;
        }

        $result = $this->request('POST', 'parse', [
            'json'    => ['raw_text' => $rawText],   // ← corrected: was 'message'
            'headers' => $headers,
        ]);

        return new ParseResult($result['body'], $result['headers']);
    }

    /**
     * Like parse(), but auto-generates a stable idempotency key from the SMS text.
     * Safe to call multiple times for the same SMS without double billing.
     */
    public function parseSafe(string $rawText): ParseResult
    {
        $key = substr(hash('sha256', $rawText), 0, 32);
        return $this->parse($rawText, $key);
    }

    /**
     * Parse up to 100 SMS messages in one request.
     *
     * @param string[] $rawTexts
     * @return array[]
     * @throws ParsePesaException|GuzzleException
     */
    public function batchParse(array $rawTexts): array
    {
        if (count($rawTexts) > 100) {
            throw new \InvalidArgumentException('Batch limit is 100 items');
        }
        $result = $this->request('POST', 'parse/batch', [   // ← corrected endpoint
            'json' => array_map(fn($t) => ['raw_text' => $t], $rawTexts),
        ]);
        return $result['body'];
    }

    /**
     * Get account balance in KES.
     * @throws ParsePesaException|GuzzleException
     */
    public function getBalance(): float
    {
        $result = $this->request('GET', 'user/stats');
        return (float) ($result['body']['balance'] ?? 0.0);
    }

    /**
     * List all API keys on this account.
     * @throws ParsePesaException|GuzzleException
     */
    public function listKeys(): array
    {
        return $this->request('GET', 'user/keys')['body'];
    }

    /**
     * Rotate an API key with zero downtime.
     * The old key stays valid for 24 hours (grace period).
     *
     * @param string $keyId Key ID from listKeys()
     * @return array{apiKey: string, graceExpiresAt: string, message: string}
     * @throws ParsePesaException|GuzzleException
     */
    public function rotateKey(string $keyId): array
    {
        return $this->request('POST', "user/keys/$keyId/rotate")['body'];
    }

    /**
     * List all webhooks on this account.
     * @throws ParsePesaException|GuzzleException
     */
    public function listWebhooks(): array
    {
        return $this->request('GET', 'user/webhooks')['body'];
    }

    /**
     * Register a new webhook.
     * @throws ParsePesaException|GuzzleException
     */
    public function createWebhook(string $url, string $name = ''): array
    {
        return $this->request('POST', 'user/webhooks', [
            'json' => ['url' => $url, 'name' => $name],
        ])['body'];
    }

    /**
     * Delete a webhook.
     * @throws ParsePesaException|GuzzleException
     */
    public function deleteWebhook(string $id): bool
    {
        $this->request('DELETE', "user/webhooks/$id");
        return true;
    }

    /**
     * Get the last 50 delivery attempts for a webhook.
     * Use this to debug failed deliveries or confirm successful ones.
     *
     * @param string $webhookId
     * @return array[] Each entry has: status, attemptCount, lastResponseCode,
     *                 deliveredAt, nextAttemptAt, lastError.
     * @throws ParsePesaException|GuzzleException
     */
    public function listWebhookDeliveries(string $webhookId): array
    {
        return $this->request('GET', "user/webhooks/$webhookId/deliveries")['body'];
    }

    /**
     * Verify an incoming webhook's HMAC-SHA256 signature.
     * Call this before processing any webhook event.
     *
     * @param string $payload   Raw request body string.
     * @param string $signature X-ParsePesa-Signature header value.
     * @param string $secret    Your webhook signing secret.
     */
    public static function verifyWebhookSignature(
        string $payload,
        string $signature,
        string $secret
    ): bool {
        $expected = hash_hmac('sha256', $payload, $secret);
        return hash_equals($expected, $signature);
    }

    /**
     * Parse and validate an incoming webhook payload from php://input.
     * Returns null if signature verification fails.
     *
     * @param string $secret Your webhook signing secret.
     */
    public function handleWebhook(string $secret): ?array
    {
        $payload = file_get_contents('php://input');
        $signature = $_SERVER['HTTP_X_PARSEPESA_SIGNATURE'] ?? '';

        if (!self::verifyWebhookSignature($payload, $signature, $secret)) {
            return null; // Signature mismatch — reject
        }

        return json_decode($payload, true) ?? [];
    }
}
