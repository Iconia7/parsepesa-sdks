export interface ParseResult {
  success: boolean;
  data: any;
}

export interface WebhookRoute {
  id: string;
  url?: string;
  destinationUrl?: string;
  name?: string;
  created_at: string;
}

export default class ParsePesa {
  constructor(apiKey: string, baseUrl?: string);

  parse(rawText: string): Promise<ParseResult>;
  batchParse(rawTexts: string[]): Promise<any>;
  getBalance(): Promise<{ success: boolean; balance: number }>;

  darajaProxy: {
    list(): Promise<WebhookRoute[]>;
    create(url: string, name: string, autoValidate?: boolean): Promise<WebhookRoute>;
    delete(id: string): Promise<boolean>;
  };

  parsingWebhooks: {
    list(): Promise<WebhookRoute[]>;
    create(url: string): Promise<WebhookRoute>;
    delete(id: string): Promise<boolean>;
  };
}
