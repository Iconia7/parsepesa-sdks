<?php

namespace ParsePesa;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

class ParsePesa
{
    private $apiKey;
    private $baseUrl;
    private $client;

    /**
     * ParsePesa constructor.
     * @param string $apiKey Your ParsePesa API Key
     * @param string $baseUrl Optional base URL for self-hosted instances
     */
    public function __construct(string $apiKey, string $baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1')
    {
        $this->apiKey = $apiKey;
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->client = new Client([
            'base_uri' => $this->baseUrl . '/',
            'headers' => [
                'Authorization' => 'Bearer ' . $this->apiKey,
                'Content-Type' => 'application/json',
                'X-SDK-Platform' => 'PHP',
                'X-SDK-Version' => '1.0.0'
            ]
        ]);
    }

    /**
     * Parse a single M-Pesa SMS message
     * @param string $message Raw SMS text
     * @return array Parsed transaction data
     * @throws GuzzleException
     */
    public function parse(string $message): array
    {
        $response = $this->client->post('parse', [
            'json' => ['message' => $message]
        ]);

        return json_decode($response->getBody()->getContents(), true);
    }

    /**
     * Parse multiple M-Pesa SMS messages in one request
     * @param array $messages List of raw SMS strings
     * @return array List of parsed results
     * @throws GuzzleException
     */
    public function batchParse(array $messages): array
    {
        $response = $this->client->post('parse/batch', [
            'json' => ['messages' => $messages]
        ]);

        return json_decode($response->getBody()->getContents(), true);
    }

    /**
     * Get your account balance (KES)
     * @return float
     * @throws GuzzleException
     */
    public function getBalance(): float
    {
        $response = $this->client->get('user/stats');
        $data = json_decode($response->getBody()->getContents(), true);
        return (float) ($data['balance'] ?? 0.0);
    }

    /**
     * Handle incoming webhooks (Callbacks or Daraja Proxy)
     * @return array
     */
    public function handleWebhook(): array
    {
        $input = file_get_contents('php://input');
        return json_decode($input, true) ?? [];
    }

    /**
     * List all your active webhooks
     * @return array
     * @throws GuzzleException
     */
    public function listWebhooks(): array
    {
        $response = $this->client->get('user/webhooks');
        return json_decode($response->getBody()->getContents(), true);
    }

    /**
     * Register a new webhook (Callback URL)
     * @param string $url The URL that will receive JSON payloads
     * @param string $description Optional description
     * @return array
     * @throws GuzzleException
     */
    public function createWebhook(string $url, string $description = ''): array
    {
        $response = $this->client->post('user/webhooks', [
            'json' => ['url' => $url, 'description' => $description]
        ]);
        return json_decode($response->getBody()->getContents(), true);
    }

    /**
     * Delete a webhook
     * @param string $id The Webhook ID
     * @return bool
     * @throws GuzzleException
     */
    public function deleteWebhook(string $id): bool
    {
        $response = $this->client->delete("user/webhooks/$id");
        return $response->getStatusCode() === 200 || $response->getStatusCode() === 204;
    }
}
