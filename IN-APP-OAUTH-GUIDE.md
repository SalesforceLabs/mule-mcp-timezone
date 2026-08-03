# In-App OAuth 2.0 Validation Guide

**Updated**: July 1, 2026  
**Status**: ✅ **Implemented and Ready for Deployment**

---

## Overview

This guide documents the **in-app OAuth 2.0 validation** approach for the Timezone MCP Server. Instead of relying on API Manager policies (which have compatibility issues with Anypoint Connected App tokens), the Mule application validates OAuth tokens directly by calling Anypoint Platform's authentication endpoint.

---

## How It Works

### Architecture

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
             │ 4. Call Anypoint: GET /accounts/api/v2/me
             │    Authorization: Bearer <token>
             │
             │ 5a. If 200 → token valid → process request
             │ 5b. If 401 → token invalid → return 401
             ▼
     JSON-RPC response
```

### Token Validation Flow

The Mule app performs these steps for every incoming request:

1. **Check for Bearer header** - Reject immediately if missing (existing defense-in-depth check)
2. **Save original payload** - Store the JSON-RPC request before HTTP call
3. **Validate token** - Call `GET https://anypoint.mulesoft.com/accounts/api/v2/me` with the Bearer token
4. **Restore payload** - Put the JSON-RPC request back for processing
5. **Process or reject**:
   - If Anypoint returns 200 → Token is valid → Parse and route the MCP request
   - If Anypoint returns 401/403 → Token is invalid → Return 401 to caller

---

## Connected App Setup

### Step 1: Create Connected App

**Access Management** → **Connected Apps** → **Create App**

| Field | Value |
|-------|-------|
| **Name** | `Timezone MCP OAuth Client` |
| **Type** | **App acts on its own behalf (client credentials)** |
| **Grant Types** | ✅ Client Credentials |
| **Redirect URIs** | (leave blank) |

### Step 2: Grant Scopes

The Connected App needs these scopes for tokens to work with `/accounts/api/v2/me`:

✅ **View Organization** (essential)  
✅ **Design Center Developer** (recommended)  
✅ **Exchange Viewer** (recommended)

**Note**: You do NOT need to configure API Manager contracts or the OAuth introspection endpoint - the in-app validation approach bypasses those entirely.

### Step 3: Save Credentials

After creating the Connected App:

```
Client ID: YOUR_CLIENT_ID
Client Secret: YOUR_CLIENT_SECRET
Token Endpoint: https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token
```

---

## Deployment

### Step 1: Upload JAR to CloudHub

1. Log into **Anypoint Platform** → **Runtime Manager**
2. If app already exists: Click **Settings** → **Choose file** → Upload new JAR
3. If new deployment: **Deploy Application** → Upload `target/timezone-mcp-server-1.0.0-mule-application.jar`

**Configuration**:
- **Runtime**: 4.6.0
- **Worker Size**: MICRO (0.1 vCores)
- **Region**: us-east-2

### Step 2: Wait for Deployment

CloudHub deployment typically takes **3-5 minutes**. Check status in Runtime Manager.

---

## Testing

### Test 1: Get OAuth Token

```bash
TOKEN=$(curl -s -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "Token: $TOKEN"
```

**Expected**: A long JWT string starting with `eyJ...`

### Test 2: Test with Valid Token

```bash
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

**Expected**: JSON response with 4 timezone tools:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {"name": "get_current_time", ...},
      {"name": "convert_time", ...},
      {"name": "time_difference", ...},
      {"name": "list_timezones", ...}
    ]
  }
}
```

### Test 3: Test without Token

```bash
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

**Expected**: 401 error:
```json
{
  "jsonrpc": "2.0",
  "id": null,
  "error": {
    "code": -32000,
    "message": "Unauthorized: Missing or invalid Bearer token"
  }
}
```

### Test 4: Test with Invalid Token

```bash
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer fake-invalid-token-12345" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

**Expected**: 401 error:
```json
{
  "jsonrpc": "2.0",
  "id": null,
  "error": {
    "code": -32000,
    "message": "Unauthorized: Invalid or expired OAuth token"
  }
}
```

### Test 5: Test a Timezone Tool

```bash
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_current_time",
      "arguments": {"city": "Tokyo"}
    }
  }'
```

**Expected**: Current time in Tokyo with timezone info.

---

## Registering with an MCP Client

Once testing is successful, register the deployed MCP server with your MCP client. You will need:

| Input | Value |
|-------|-------|
| **URL** | `https://{your-app-url}/mcp` |
| **Authentication** | OAuth 2.0 |
| **Token Endpoint** | `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token` |
| **Grant Type** | Client Credentials |
| **Client ID** | `YOUR_CLIENT_ID` |
| **Client Secret** | `YOUR_CLIENT_SECRET` |

The client will get a token from Anypoint using the credentials, call the server with `Authorization: Bearer <token>`, and discover the 4 tools.

> To register this MCP server in Salesforce (or another MCP client), refer to the accompanying blog post.

---

## Monitoring

### CloudHub Logs

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

### Performance

Token validation adds ~100-200ms latency per request:
- Network call to Anypoint Platform
- Token validation processing
- Acceptable for AI agent tools (not real-time APIs)

---

## Troubleshooting

### Error: "Missing or invalid Bearer token"

**Cause**: No Authorization header or wrong format

**Fix**:
```bash
# Ensure header format is exactly: Authorization: Bearer <token>
curl -H "Authorization: Bearer $TOKEN" ...
```

### Error: "Invalid or expired OAuth token"

**Cause**: Token rejected by Anypoint `/me` endpoint

**Possible reasons**:
1. Token expired (tokens last 1 hour)
2. Invalid client_id/client_secret used to generate token
3. Connected App doesn't have required scopes

**Fix**:
```bash
# Get a fresh token
TOKEN=$(curl -s -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -d "grant_type=client_credentials&client_id=YOUR_ID&client_secret=YOUR_SECRET" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

# Verify token works with /me endpoint directly
curl -H "Authorization: Bearer $TOKEN" https://anypoint.mulesoft.com/accounts/api/v2/me
```

### MCP Client Discovers 0 Tools

**Possible causes**:
- Wrong URL (check for typos)
- Wrong Token Endpoint URL
- Invalid client credentials

**Debug**:
1. Test OAuth flow manually with curl (see Test 1-5 above)
2. Check CloudHub logs for incoming requests
3. Verify token endpoint URL is exactly: `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token`

### CloudHub Deployment Stuck

**Symptoms**: Status shows "Deploying..." for >10 minutes

**Fix**:
1. Check **Runtime Manager** → **Applications** → **timezone-mcp-server** → **Logs**
2. Look for errors in the last 50 lines
3. Common issues:
   - Port conflict: Check if another app is using port 8081
   - XML syntax error: Validate the Mule config file
   - Resource exhaustion: Stop unused apps to free vCores

---

## Security Considerations

### Defense-in-Depth

The app has **two layers** of authentication:

1. **Bearer header check** (line 62) - Fast string check, blocks obviously invalid requests
2. **OAuth token validation** (lines 95-110) - Real validation against Anypoint Platform

### Token Lifetime

- Anypoint OAuth tokens expire after **1 hour**
- The MCP client automatically refreshes tokens as needed
- No manual token rotation required

### Production Recommendations

For production deployments:

1. **Use environment variables** for sensitive config (not hardcoded)
2. **Monitor failed auth attempts** - Set up alerts for repeated 401 errors
3. **Rate limiting** - Add rate limiting if exposed to public internet
4. **Separate Connected Apps** - Different credentials for Sandbox vs Production
5. **Rotate credentials** - Update client_id/client_secret every 90 days

---

## Next Steps

After successful deployment and testing, register the MCP server with your MCP client using the endpoint URL and Connected App credentials (see "Registering with an MCP Client" above).

> To register this MCP server in Salesforce (or another MCP client), refer to the accompanying blog post.

---

## Success Criteria

✅ Build succeeds - `timezone-mcp-server-1.0.0-mule-application.jar` created  
✅ CloudHub deployment status: "Started"  
✅ curl without token → 401  
✅ curl with valid token → 4 tools returned  
✅ curl with invalid token → 401  
✅ MCP client discovers 4 tools  

**Status**: ✅ **Implementation complete - ready for deployment**

---

## Related Files

```
mule-mcp-timezone/
├── src/main/mule/
│   └── timezone-mcp-server.xml   ← MCP server source (OAuth validation included)
├── IN-APP-OAUTH-GUIDE.md         ← This file
├── DEPLOYMENT-CHECKLIST.md       ← Step-by-step MuleSoft deployment & testing
├── test-oauth.sh                 ← OAuth functionality tests
└── test-mcp-compliance.sh        ← MCP protocol compliance tests
```

---

**Status**: ✅ Complete and tested  
**JAR Version**: 1.0.0 (includes OAuth validation)
