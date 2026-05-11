class ParsePesa {
  constructor(apiKey, baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1') {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.headers = {
      'Authorization': `Bearer ${this.apiKey}`,
      'Content-Type': 'application/json'
    };
    
    // Managers
    this.darajaProxy = new WebhooksManager(this, '/user/daraja-proxy');
    this.parsingWebhooks = new WebhooksManager(this, '/user/webhooks');
  }

  async _request(path, options = {}) {
    const url = `${this.baseUrl}${path}`;
    const response = await fetch(url, {
      ...options,
      headers: { ...this.headers, ...options.headers }
    });
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `Request failed with status ${response.status}`);
    }
    
    return response.json();
  }

  async parse(rawText) {
    return this._request('/parse', {
      method: 'POST',
      body: JSON.stringify({ raw_text: rawText })
    });
  }

  async batchParse(rawTexts) {
    return this._request('/batch-parse', {
      method: 'POST',
      body: JSON.stringify({ messages: rawTexts })
    });
  }

  async getBalance() {
    const data = await this._request('/user/stats');
    return { success: true, balance: data.balance || 0 };
  }
}

class WebhooksManager {
  constructor(client, endpoint) {
    this.client = client;
    this.endpoint = endpoint;
  }

  async list() {
    return this.client._request(this.endpoint);
  }

  async create(url, name, autoValidate = true) {
    return this.client._request(this.endpoint, {
      method: 'POST',
      body: JSON.stringify({
        url,
        destinationUrl: url, // Compatibility
        name,
        autoValidate
      })
    });
  }

  async delete(id) {
    const response = await fetch(`${this.client.baseUrl}${this.endpoint}/${id}`, {
      method: 'DELETE',
      headers: this.client.headers
    });
    return response.ok;
  }
}

module.exports = ParsePesa;
