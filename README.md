# Timezone MCP Server

A MuleSoft MCP (Model Context Protocol) server that provides world clock and timezone conversion tools to MCP-compatible AI agents (such as Salesforce Agentforce). Secured with OAuth 2.0 via an Anypoint Platform Connected App.

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

---

# Deployment Guide

This guide walks you through deploying the Timezone MCP server to your own MuleSoft (Anypoint) instance, from a fresh account all the way to a running, authenticated server. Follow the steps in order.

## How Authentication Works

This server uses OAuth 2.0 **Client Credentials** grant with **in-app token validation**. Instead of relying on API Manager policies (which have compatibility issues with Anypoint Connected App tokens), the Mule application validates OAuth tokens directly by calling Anypoint Platform's authentication endpoint.

```
┌───────────────────────────┐
│  MCP Client (e.g.         │
│  Salesforce Agentforce)   │
└────────────┬──────────────┘
             │
             │ 1. Get OAuth token (client_credentials grant)
             │    POST /accounts/api/v2/oauth2/token
             │    Body: client_id + client_secret
             │
             │ 2. Call MCP server with Bearer token
             │    Authorization: Bearer <token>
             ▼
┌─────────────────────────┐
│ timezone-mcp-server     │
│ (CloudHub)              │
└────────────┬────────────┘
             │
             │ 3. Extract Bearer token from header
             │ 4. Call Anypoint: GET /accounts/api/profile
             │    Authorization: Bearer <token>
             │
             │ 5a. If 200 → token valid → process request
             │ 5b. If 401 → token invalid → return 401
             ▼
     JSON-RPC response
```

The Mule app performs these steps for every incoming request:

1. **Check for Bearer header** — reject immediately if missing (defense-in-depth check)
2. **Save the original payload** — store the JSON-RPC request before the HTTP call
3. **Validate the token** — call `GET https://anypoint.mulesoft.com/accounts/api/profile` with the Bearer token (returns 200 for a valid token, 401 for an invalid one; works with client-credentials tokens, which have no user)
4. **Restore the payload** — put the JSON-RPC request back for processing
5. **Process or reject** — 200 from Anypoint routes the MCP request; 401/403 returns 401 to the caller

**No API Manager dependency** — all authentication logic runs entirely within the Mule application.

Token endpoint: `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token`

## Why Not the Anypoint Connector for MCP?

MuleSoft offers an [Anypoint Connector for MCP](https://docs.mulesoft.com/mcp-connector/latest/) (Select-level) that handles the MCP protocol plumbing automatically — no manual JSON-RPC routing, `initialize` handshake, or `tools/list` generation needed. This project deliberately avoids it for two reasons:

1. **Build-time credentials** — The connector is hosted on the Anypoint Exchange Maven repository, which requires authenticated credentials in `~/.m2/settings.xml`. Without them, `mvn clean package` fails with a 401. All dependencies in this project resolve from the public MuleSoft releases repository, so the build works without any Anypoint credentials.

2. **License requirement** — The MCP Connector is a Select-level connector, which requires a paid Anypoint Platform subscription. This project is designed to run on a free 30-day Anypoint trial account (CloudHub 2.0 Sandbox), where Select connectors are not available.

The MCP protocol is implemented directly using the HTTP Connector and DataWeave, so this server works on any Mule 4.9+ runtime with no paid-tier connector dependencies.

## Prerequisites

- **Maven 3.x** and **JDK 17** (to build the deployable JAR)
- An **MCP client** (such as Salesforce Agentforce) to register and call the server once it is deployed

Everything else — the Anypoint account and the Connected App — is created in the steps below.

> [!IMPORTANT]
> This guide runs helper scripts from the [`scripts/`](scripts/) folder. Make sure they're executable before you start. If you hit a `permission denied` error, mark them executable for your OS:
>
> ```bash
> # macOS and Linux
> chmod +x scripts/*.sh
> ```
>
> ```bash
> # Windows — Git Bash or WSL
> chmod +x scripts/*.sh
> ```
>
> On **native Windows** (PowerShell/CMD), these Bash scripts don't run directly — use Git Bash or WSL, or invoke them explicitly with `bash scripts/<name>.sh` (no `chmod` needed when invoked this way).

## Step 1: Create an Anypoint Platform Account

1. Go to <https://anypoint.mulesoft.com>
2. Sign up for a **free 30-day trial** (or log in if you already have an account)
3. Your trial includes a **Sandbox** environment with CloudHub 2.0 enabled — that is all you need for this deployment

## Step 2: Create the Connected App

The Connected App provides the OAuth credentials the MCP client uses to authenticate, and the same credentials let the Mule app validate tokens against Anypoint.

### 2.1 Create the app

Go to **Settings** → **Access Management** → **Connected Apps** → **Create App**, then fill in the form:

- **Name**: `Timezone MCP OAuth Client`
- **Type**: select **App acts on its own behalf (client credentials)**

### 2.2 Grant scopes

Before saving, click **Add Scopes** on the Create App screen. This opens a 3-step wizard:

1. **Add Scopes** — check the scopes the app needs for tokens to work with `/accounts/api/profile`, then click **Next**:
   - ✅ **View Organization** (essential) — under the *General* group
   - ✅ **Design Center Developer** (recommended) — under the *Design Center* group
   - ✅ **Exchange Viewer** (recommended) — under the *Exchange* group
2. **Select Business Groups** — check your business group, then click **Next**. Each selected scope is applied to that group.
3. **Review** — confirm the scope/business-group pairings, then click **Add Scopes**.

Back on the Create App screen, click **Save** to create the app.

> [!NOTE]
> You do **not** need to configure API Manager contracts or the OAuth introspection endpoint — the in-app validation approach bypasses those entirely.

### 2.3 Save your credentials

After creating the Connected App, copy the credentials — you will need them when deploying, testing, and registering the server:

```
Client ID:      YOUR_CLIENT_ID
Client Secret:  YOUR_CLIENT_SECRET
Token Endpoint: https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token
```

Create your local `.env` from the template and fill in these two values now — the test scripts read from it (`.env` is gitignored, so your credentials stay local):

```bash
cp .env.example .env
```

Then set in `.env`:

```
CLIENT_ID=<your Client ID>
CLIENT_SECRET=<your Client Secret>
```

You'll fill in `MCP_URL` after deploying (Step 4).

### 2.4 Verify the credentials work

Confirm the credentials in your `.env` can generate a token:

```bash
./scripts/verify-credentials.sh
```

**Expected**: `✓ Credentials valid — token obtained`

## Step 3: Build the JAR

Build the deployable Mule application from source:

```bash
./scripts/build.sh
# runs `mvn clean package` and produces:
# target/timezone-mcp-server-1.0.0-mule-application.jar
```

> [!NOTE]
> Mule 4.9 must be built with **Java 17**. `scripts/build.sh` automatically locates a Java 17 JDK and uses it for the build; if it can't find one, it prints the install command and exits. If you'd rather set things up yourself first, follow the steps for your OS below.

<details>
<summary><strong>macOS setup</strong></summary>

```bash
# Install Java 17 and Maven (skip either if already installed)
brew install openjdk@17
brew install maven

# Point Maven at Java 17 (Maven uses JAVA_HOME, which can differ from `java` on PATH)
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Verify Maven picks up Java 17 (look for "Java version: 17.x")
mvn -version

# Build
./scripts/build.sh
```
</details>

<details>
<summary><strong>Linux setup</strong></summary>

```bash
# Install Java 17 and Maven (Debian/Ubuntu; use your distro's equivalent otherwise)
sudo apt-get install openjdk-17-jdk maven

# Point Maven at Java 17 (adjust the path if your JDK is elsewhere)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Verify Maven picks up Java 17 (look for "Java version: 17.x")
mvn -version

# Build
./scripts/build.sh
```
</details>

<details>
<summary><strong>Windows setup</strong></summary>

`scripts/build.sh` is a Bash script, so on Windows either build inside **WSL / Git Bash** (follow the Linux steps above), or build natively with **PowerShell** and Maven:

```powershell
# Install Java 17 and Maven (using winget; or install manually)
winget install EclipseAdoptium.Temurin.17.JDK
winget install Apache.Maven

# Point Maven at Java 17 (adjust the path to your JDK install)
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17"

# Verify Maven picks up Java 17 (look for "Java version: 17.x")
mvn -version

# Build (scripts/build.sh's job — produces the same JAR under target\)
mvn clean package
```
</details>

### Verify the build

Confirm the JAR was produced and includes the OAuth validation config:

```bash
./scripts/verify-build.sh
```

**Expected**:
```
✓ JAR built: target/timezone-mcp-server-1.0.0-mule-application.jar
✓ OAuth config present (http:request-config name="anypoint-auth-config")
Build verified.
```

## Step 4: Deploy to CloudHub

1. In Anypoint Platform, open **Runtimes** → **Runtime Manager** → **Deploy application**
2. Select the **Sandbox** environment when prompted
3. Configure the deployment:
   - **Application Name**: `timezone-mcp-server` (or another unique name)
   - Leave the default option in **Deployment Target**, just make sure it's CloudHub 2.0
   - Upload the JAR in **Application File**
   - **Runtime version**: At least Long-Term Support, `4.9.x`. Otherwise, any latest version (Edge) is ok as long as Java 17 is selected.
   - **Java Version**: Java 17 (even if it can't be changed, verify it is selected)
   - **Replica Count:** 1
   - **Replica Size**: MICRO (0.1 vCores)
4. Click **Deploy Application**
5. Go to the **Dashboard**
6. Watch the status change from `🔴 Not Running...` to `🟢 Running` — this typically takes **3–5 minutes**

Your endpoint will be `https://{your-app-name}-{random-chars}.{region}.cloudhub.io/mcp`. You can find the exact URL on the **Dashboard** of your deployed app.

Add this URL to your `.env` (created in Step 2.3) so the test scripts can reach the server:

```
MCP_URL=https://{your-app-url}/mcp
```

> [!IMPORTANT]
> Make sure the URL ends in `/mcp`. The URL shown on the CloudHub Dashboard is just the base app URL — it does **not** include the `/mcp` path — so you have to append it yourself when setting `MCP_URL`.

### If deployment gets stuck (>10 minutes)

1. Open the **Logs** tab and check the last 50 lines for errors
2. Common issues:
   - **Port conflict** → stop other apps using the same port
   - **XML syntax error** → rebuild the JAR
   - **Resource exhaustion** → stop unused apps to free vCores

## Step 5: Test the Deployment

### 5.1 Quick smoke test (no token → 401)

Confirm the server rejects unauthenticated requests. This reads `MCP_URL` from your `.env` (set in Step 4):

```bash
./scripts/smoke-test.sh
```

**Expected**: A 401 — `✓ Correctly rejected unauthenticated request (HTTP 401)`

### 5.2 Automated test suites

Both scripts read `MCP_URL`, `CLIENT_ID`, and `CLIENT_SECRET` from your `.env` file. If you filled it in during Steps 2.3 and 4, just run them:

**OAuth Tests:**

```bash
# OAuth functionality tests
./scripts/test-oauth.sh
```

**Expected**:
```
✓ Token obtained
✓ Correctly rejected unauthenticated request
✓ Correctly rejected invalid token
✓ Successfully authenticated and got tools
✓ Tool call successful
```

**MCP Compliance Tests:**

```bash
# Full MCP protocol compliance suite
./scripts/test-mcp-compliance.sh
```

**Expected**:
```
Total Tests: 51
Passed: 51
Failed: 0

✓ MCP Server is fully compliant!
```

The compliance suite covers the core MCP protocol (initialize, notifications), tools discovery (`tools/list`), execution of all 4 tools, error handling (unknown methods, invalid tokens), and JSON-RPC 2.0 compliance.

### 5.3 Manual tool testing

Get a token, then exercise each tool:

```bash
# Load your credentials and MCP URL from .env
set -a; . ./.env; set +a

# Get an OAuth token
TOKEN=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" \
  | jq -r '.access_token')

# 1. get_current_time
curl -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_current_time","arguments":{"city":"Tokyo"}}}'

# 2. convert_time
curl -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"convert_time","arguments":{"time":"15:00","from_city":"New York","to_city":"London"}}}'

# 3. time_difference
curl -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"time_difference","arguments":{"city1":"New York","city2":"Tokyo"}}}'

# 4. list_timezones
curl -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"list_timezones","arguments":{"region":"Asia"}}}'
```

### Deployment is successful when:

1. CloudHub deployment status is **Started**
2. The endpoint returns **401 without a token** and valid results **with a token**
3. `./scripts/test-mcp-compliance.sh` passes all 51 tests
4. All 4 tools return correct results

---

## Step 6: Register with an MCP Client

Once testing passes, register the deployed server with your MCP client (such as Salesforce Agentforce). Provide:

| Input | Value |
|-------|-------|
| **URL** | `https://{your-app-url}/mcp` |
| **Authentication** | OAuth 2.0 |
| **Token Endpoint** | `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token` |
| **Grant Type** | Client Credentials |
| **Client ID** | `YOUR_CLIENT_ID` |
| **Client Secret** | `YOUR_CLIENT_SECRET` |

The client obtains a token from Anypoint using the credentials, calls the server with `Authorization: Bearer <token>`, and discovers the 4 tools automatically.

> To register this MCP server in Salesforce (or another MCP client), refer to the accompanying blog post.

---

## Monitoring

Check **Runtime Manager** → **timezone-mcp-server** → **Logs** for:

**Successful requests**:
```
INFO  OAuth token validated successfully
INFO  MCP Request - Method: tools/list, ID: 1
```

**Failed authentication**:
```
WARN  OAuth token validation failed: HTTP:UNAUTHORIZED
```

**Performance**: Token validation adds ~100–200ms latency per request (a network call to Anypoint Platform plus validation processing) — acceptable for AI agent tools that are not real-time APIs.

---

## Troubleshooting

### Token generation fails

**Symptom**: `curl` to the token endpoint returns an error.

**Check**:
1. Client ID and Client Secret are correct
2. The Connected App exists and is active
3. The Connected App has the **View Organization** scope

**Fix**: Recreate the Connected App with the correct scopes (see [Step 2](#step-2-create-the-connected-app)).

### "Missing or invalid Bearer token"

**Cause**: No Authorization header, or wrong format.

**Fix**: Ensure the header format is exactly `Authorization: Bearer <token>`.

### "Invalid or expired OAuth token" (401 with a valid-looking token)

**Cause**: The token was rejected by Anypoint's `/accounts/api/profile` endpoint.

**Possible reasons**:
1. Token expired (tokens last 1 hour)
2. Invalid client_id/client_secret used to generate the token
3. The Connected App lacks the required scopes

**Fix**: Get a fresh token and verify it works directly against Anypoint:

```bash
TOKEN=$(curl -s -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -d "grant_type=client_credentials&client_id=YOUR_ID&client_secret=YOUR_SECRET" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

# Should return 200 if the token is valid
curl -H "Authorization: Bearer $TOKEN" https://anypoint.mulesoft.com/accounts/api/profile
```

### MCP client discovers 0 tools

**Possible causes**: wrong server URL, wrong token endpoint URL, or invalid client credentials.

**Debug**:
1. Test the OAuth flow manually with curl (see [Step 5](#step-5-test-the-deployment))
2. Check CloudHub logs for incoming requests
3. Verify the token endpoint is exactly `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token`

---

## Security Considerations

**Defense-in-depth** — the app has two layers of authentication: a fast Bearer header check that blocks obviously invalid requests, and real OAuth token validation against Anypoint Platform.

**Token lifetime** — Anypoint OAuth tokens expire after 1 hour. The MCP client refreshes them automatically; no manual rotation is required.

**For production deployments**:
1. Use **environment variables** for sensitive config (not hardcoded values)
2. **Monitor failed auth attempts** — alert on repeated 401 errors
3. Add **rate limiting** if the server is exposed to the public internet
4. Use **separate Connected Apps** for Sandbox vs. Production
5. **Rotate credentials** every 90 days

---

## Project Files

```
mule-mcp-timezone/
├── src/main/mule/
│   └── timezone-mcp-server.xml       ← MCP server source (OAuth validation included)
├── scripts/
│   ├── build.sh                      ← Builds the deployable JAR (mvn clean package)
│   ├── verify-build.sh               ← Checks the built JAR exists and has the OAuth config
│   ├── verify-credentials.sh         ← Checks Connected App credentials via a token request
│   ├── smoke-test.sh                 ← Confirms the deployed server rejects unauthenticated requests (401)
│   ├── test-oauth.sh                 ← OAuth functionality tests
│   └── test-mcp-compliance.sh        ← MCP protocol compliance tests
├── .env.example                      ← Template for local config (copy to .env)
└── README.md                         ← This file (single source of truth)
```
