'use strict';

const crypto = require('crypto');

/**
 * ParsePesa Node.js SDK — v2.0.0
 *
 * Changelog v2.0:
 *   - parse() accepts idempotencyKey to prevent double billing on retries
 *   - ParseResult class exposes isReplay, idempotencyStored, requestId
 *   - rotateKey() — zero-downtime key rotation with 24h grace period
 *   - webhooks.deliveries() — view delivery history
 *   - Corrected batch endpoint (/parse/batch not /batch-parse)
 *   - _request() throws ParsePesaError on non-2xx (with .statusCode and .code)
 *   - verifyWebhookSignature() static helper
 */

class ParsePesaError extends Error {
  constructor(message, statusCode, code) {
    super(message);
    this.name = 'ParsePesaError';
    this.statusCode = statusCode;
    this.code = code; // e.g. 'BALANCE_RACE'
  }
}

class ParseResult {
  constructor(data, headers) {
    this._data = data;
    this._headers = headers || {};
  }

  get success() { return this._data.success === true; }
  get confidence() { return this._data.confidence ?? 0; }
  get transaction() { return this._data.data ?? {}; }
  get errorMessage() { return this._data.errorMessage ?? null; }

  /** True if this response was served from the idempotency cache (no charge). */
  get isReplay() {
    return (this._headers['x-idempotent-replay'] ?? '').toLowerCase() === 'true';
  }

  /**
   * False if idempotency record could not be persisted after billing.
   * If false: do NOT retry with the same key — it will not deduplicate.
   */
  get idempotencyStored() {
    return (this._headers['x-idempotency-stored'] ?? 'true').toLowerCase() !== 'false';
  }

  get requestId() { return this._headers['x-request-id'] ?? null; }

  toJSON() { return this._data; }
}

class ParsePesa {
  static SDK_VERSION = '2.0.0';

  constructor(apiKey, baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1') {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this._defaultHeaders = {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'X-SDK-Platform': 'Node',
      'X-SDK-Version': ParsePesa.SDK_VERSION,
    };
    this.webhooks = new WebhooksManager(this, '/user/webhooks');
    this.darajaProxy = new WebhooksManager(this, '/user/daraja-proxy');
  }

  async _request(method, path, { body, extraHeaders } = {}) {
    const url = `${this.baseUrl}${path}`;
    const response = await fetch(url, {
      method,
      headers: { ...this._defaultHeaders, ...extraHeaders },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });

    const responseHeaders = Object.fromEntries(response.headers.entries());

    if (!response.ok) {
      let data = {};
      try { data = await response.json(); } catch (_) { }
      throw new ParsePesaError(
        data.error ?? `Request failed: ${response.status}`,
        response.status,
        data.code ?? null,
      );
    }

    return { data: await response.json(), headers: responseHeaders };
  }

  /**
   * Parse a single M-Pesa SMS message.
   *
   * @param {string} rawText - The raw SMS string.
   * @param {object} [options]
   * @param {string} [options.idempotencyKey] - Unique key (max 128 chars) to prevent
   *   double billing on retries. Recommended: hash of the SMS text.
   * @returns {Promise<ParseResult>}
   * @throws {ParsePesaError} on non-2xx (including 402 insufficient balance)
   */
  async parse(rawText, { idempotencyKey } = {}) {
    const extraHeaders = {};
    if (idempotencyKey) extraHeaders['X-Idempotency-Key'] = String(idempotencyKey);

    const { data, headers } = await this._request('POST', '/parse', {
      body: { raw_text: rawText },
      extraHeaders,
    });
    return new ParseResult(data, headers);
  }

  /**
   * Like parse(), but auto-generates an idempotency key from the SMS text.
   * Safe to call multiple times for the same SMS.
   */
  async parseSafe(rawText) {
    const key = crypto.createHash('sha256').update(rawText).digest('hex').slice(0, 32);
    return this.parse(rawText, { idempotencyKey: key });
  }

  /**
   * Parse up to 100 SMS messages in one request.
   * @param {string[]} rawTexts
   * @returns {Promise<object[]>}
   */
  async batchParse(rawTexts) {
    if (rawTexts.length > 100) throw new ParsePesaError('Batch limit is 100 items', 400);
    const { data } = await this._request('POST', '/parse/batch', {   // ← corrected endpoint
      body: rawTexts.map(t => ({ raw_text: t })),
    });
    return data;
  }

  /** Returns account balance in KES. */
  async getBalance() {
    const { data } = await this._request('GET', '/user/stats');
    return data.balance ?? 0;
  }

  /** Returns full account stats object. */
  async getStats() {
    const { data } = await this._request('GET', '/user/stats');
    return data;
  }

  /** List all API keys on this account. */
  async listKeys() {
    const { data } = await this._request('GET', '/user/keys');
    return data;
  }

  /**
   * Rotate an API key with zero downtime.
   * The old key stays valid for 24 hours (grace period).
   *
   * @param {string} keyId - The key ID to rotate (from listKeys())
   * @returns {Promise<{apiKey: string, graceExpiresAt: string, message: string}>}
   */
  async rotateKey(keyId) {
    const { data } = await this._request('POST', `/user/keys/${keyId}/rotate`);
    return data;
  }

  /**
   * Verify an incoming webhook's HMAC-SHA256 signature.
   * Call this before processing any webhook event.
   *
   * @param {Buffer|string} payload - Raw request body.
   * @param {string} signature - X-ParsePesa-Signature header value.
   * @param {string} secret - Your webhook secret.
   * @returns {boolean}
   */
  static verifyWebhookSignature(payload, signature, secret) {
    const expected = crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('hex');
    return crypto.timingSafeEqual(
      Buffer.from(expected, 'hex'),
      Buffer.from(signature, 'hex'),
    );
  }
}

class WebhooksManager {
  constructor(client, path) {
    this._client = client;
    this._path = path;
  }

  async list() {
    const { data } = await this._client._request('GET', this._path);
    return data;
  }

  async create(url, { name, autoValidate = true } = {}) {
    const { data } = await this._client._request('POST', this._path, {
      body: { url, destinationUrl: url, name, autoValidate },
    });
    return data;
  }

  async delete(id) {
    await this._client._request('DELETE', `${this._path}/${id}`);
    return true;
  }

  /**
   * Get the last 50 delivery attempts for a webhook.
   * Useful for debugging failed deliveries.
   *
   * @param {string} webhookId
   * @returns {Promise<object[]>} Each entry has: status, attemptCount,
   *   lastResponseCode, deliveredAt, nextAttemptAt, lastError.
   */
  async deliveries(webhookId) {
    const { data } = await this._client._request(
      'GET', `${this._path}/${webhookId}/deliveries`
    );
    return data;
  }
}

module.exports = { ParsePesa, ParsePesaError, ParseResult, WebhooksManager };
