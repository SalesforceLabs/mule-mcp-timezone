# Timezone MCP Server

A MuleSoft MCP (Model Context Protocol) server that provides world clock and timezone conversion tools to MCP-compatible AI agents (such as Salesforce Agentforce). Secured with OAuth 2.0 via Anypoint Platform Connected App.

## Tools

| Tool | Description | Example |
|------|-------------|---------|
| `get_current_time` | Current date/time for any city | "Tokyo" → "Tuesday, July 1, 2026 10:30 PM JST" |
| `convert_time` | Convert time between zones | "14:30 from NYC to London" → "2:30 PM EDT = 7:30 PM BST" |
| `time_difference` | Hours between two cities | "Tokyo vs NYC" → "Tokyo is 13 hours ahead" |
| `list_timezones` | Available cities by region | "Asia" → Bangkok, Singapore, Tokyo... |

## Supported Cities (60+)

**Americas**: New York, Los Angeles, Chicago, Denver, Phoenix, Houston, Dallas, Miami, Seattle, Boston, Washington DC, Atlanta, Toronto, Vancouver, Mexico City, Sao Paulo, Buenos Aires

**Europe**: London, Paris, Berlin, Madrid, Rome, Amsterdam, Zurich, Moscow, Istanbul

**Asia**: Dubai, Riyadh, Mumbai, Delhi, Bangalore, Chennai, Kolkata, Karachi, Dhaka, Bangkok, Singapore, Kuala Lumpur, Jakarta, Hong Kong, Shanghai, Beijing, Taipei, Seoul, Tokyo

**Australia/Pacific**: Sydney, Melbourne, Brisbane, Perth, Auckland, Honolulu

Also accepts IANA timezone IDs directly (e.g., `America/New_York`, `Asia/Kolkata`).

## Deployment

Follow these steps to deploy this MCP server to your own MuleSoft (Anypoint) instance.

### Prerequisites

- **Anypoint Platform account** with a CloudHub 2.0-enabled environment
- **Maven 3.x** and **JDK 8 or 11** (to build the deployable JAR)
- An Anypoint **Connected App** using the `client_credentials` grant — used for in-app OAuth token validation (see [IN-APP-OAUTH-GUIDE.md](IN-APP-OAUTH-GUIDE.md))
- An **MCP client** (such as Salesforce Agentforce) to register and call the server — see [Using with an MCP Client](#using-with-an-mcp-client) below

### 1. Build the JAR

```bash
./deploy.sh
# produces target/timezone-mcp-server-1.0.0-mule-application.jar
```

### 2. Deploy to CloudHub (Runtime Manager)

1. Anypoint Platform → **Runtime Manager** → **Deploy application**
2. Set the deployment options:
   - **Application name**: a unique name (e.g. `timezone-mcp-server`)
   - **Runtime version**: `4.6.0`
   - **Worker size**: MICRO (0.1 vCores)
   - **Workers**: 1
   - **Region**: your preferred region
3. Upload the JAR from step 1, then click **Deploy Application**
4. Wait 3–5 minutes for the status to reach `Started`

Your endpoint will be `https://{app-name}.{region}.cloudhub.io/mcp`.

### 3. Verify

```bash
# Should return 401 (no token supplied)
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

# Full MCP compliance suite
./test-mcp-compliance.sh
```

> For the full step-by-step MuleSoft deployment and testing procedure, see **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)**. For OAuth Connected App setup, see **[IN-APP-OAUTH-GUIDE.md](IN-APP-OAUTH-GUIDE.md)**.

## Using with an MCP Client

Once the server is deployed and tested, register it with your MCP client (such as Salesforce Agentforce). The client needs your deployed endpoint (`https://{your-app-url}/mcp`), the Anypoint token endpoint, and the Connected App Client ID / Secret — it obtains a token and discovers the 4 tools automatically.

> To register this MCP server in Salesforce (or another MCP client), refer to the accompanying blog post.

## Authentication

Uses OAuth 2.0 Client Credentials grant with **in-app token validation**:

1. **Connected App** created in Anypoint Access Management (client_credentials type)
2. **Mule app validates tokens** by calling Anypoint's `/accounts/api/v2/me` endpoint
3. **The MCP client** (e.g. Salesforce) authenticates using the Connected App credentials at MCP server registration

Token endpoint: `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token`

**No API Manager dependency** — authentication logic runs entirely within the Mule application.

See [IN-APP-OAUTH-GUIDE.md](IN-APP-OAUTH-GUIDE.md) for detailed implementation and configuration.

## Testing

```bash
# Get OAuth token
TOKEN=$(curl -s -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" | jq -r '.access_token')

# Get current time in Tokyo
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_current_time","arguments":{"city":"Tokyo"}}}'
```

## Documentation

- [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md) — Step-by-step MuleSoft deployment and testing procedure
- [IN-APP-OAUTH-GUIDE.md](IN-APP-OAUTH-GUIDE.md) — OAuth 2.0 in-app validation implementation and Connected App setup
