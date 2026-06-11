export interface ParseTransaction {
  transactionId: string;
  type: 'send_money' | 'till_payment' | 'paybill' | 'withdrawal' | 'airtime' | 'incoming' | 'deposit' | 'loan';
  amount: number;
  currency: string;
  counterparty: string;
  balance: number;
  fee: number;
  status: 'completed' | 'pending' | 'approved' | 'declined';
  timestamp: string; // ISO 8601
}

export interface ParseResultData {
  success: boolean;
  confidence: number;
  parserVersion: string;
  data: ParseTransaction | null;
  errorMessage: string | null;
}

export declare class ParsePesaError extends Error {
  statusCode: number;
  /** e.g. 'BALANCE_RACE' on concurrent billing collision */
  code: string | null;
}

export declare class ParseResult {
  readonly success: boolean;
  readonly confidence: number;
  readonly transaction: ParseTransaction | Record<string, never>;
  readonly errorMessage: string | null;
  /** True if response was from idempotency cache — you were not charged. */
  readonly isReplay: boolean;
  /**
   * False if idempotency record could not be persisted after billing.
   * Do NOT retry with the same key if this is false.
   */
  readonly idempotencyStored: boolean;
  readonly requestId: string | null;
  toJSON(): ParseResultData;
}

export interface ParseOptions {
  /** Unique key (max 128 chars) to prevent double billing on retries. */
  idempotencyKey?: string;
}

export interface WebhookDelivery {
  id: string;
  eventType: string;
  status: 'pending' | 'delivered' | 'failed' | 'exhausted';
  attemptCount: number;
  maxAttempts: number;
  lastResponseCode: number | null;
  lastError: string | null;
  deliveredAt: string | null;
  createdAt: string;
  nextAttemptAt: string | null;
}

export interface RotateKeyResult {
  apiKey: string;
  name: string;
  graceExpiresAt: string;
  message: string;
}

export declare class WebhooksManager {
  list(): Promise<object[]>;
  create(url: string, options?: { name?: string; autoValidate?: boolean }): Promise<object>;
  delete(id: string): Promise<boolean>;
  /** Get last 50 delivery attempts for a webhook. */
  deliveries(webhookId: string): Promise<WebhookDelivery[]>;
}

export declare class ParsePesa {
  static readonly SDK_VERSION: string;

  webhooks: WebhooksManager;
  darajaProxy: WebhooksManager;

  constructor(apiKey: string, baseUrl?: string);

  /** Parse a single M-Pesa SMS. Optionally pass idempotencyKey to prevent double billing. */
  parse(rawText: string, options?: ParseOptions): Promise<ParseResult>;

  /** Like parse(), but auto-generates idempotency key from SMS text. Safe for retries. */
  parseSafe(rawText: string): Promise<ParseResult>;

  /** Parse up to 100 SMS messages in one request. */
  batchParse(rawTexts: string[]): Promise<ParseResultData[]>;

  /** Get account balance in KES. */
  getBalance(): Promise<number>;

  /** Get full account stats. */
  getStats(): Promise<object>;

  /** List all API keys on this account. */
  listKeys(): Promise<object[]>;

  /** Rotate an API key with zero downtime (24h grace period on old key). */
  rotateKey(keyId: string): Promise<RotateKeyResult>;

  /** Verify an incoming webhook's HMAC-SHA256 signature. */
  static verifyWebhookSignature(
    payload: Buffer | string,
    signature: string,
    secret: string
  ): boolean;
}

export { ParsePesa as default };
