# Timezone MCP Server - Deployment Checklist

**Version**: 1.0.0  
**Date**: July 1, 2026  
**Status**: ✅ Ready for Deployment

This guide covers deploying the Timezone MCP server to your own MuleSoft (Anypoint) instance. To register the deployed server in Salesforce (or another MCP client), refer to the accompanying blog post.

---

## Quick Start (5 Minutes)

If you just want to deploy and test:

1. **Build the JAR**
   ```bash
   ./deploy.sh
   ```

2. **Upload JAR to CloudHub**
   ```
   Runtime Manager → timezone-mcp-server → Settings → Choose file
   → Upload: target/timezone-mcp-server-1.0.0-mule-application.jar
   ```

3. **Wait for deployment** (3-5 minutes)

4. **Run test suite**
   ```bash
   ./test-mcp-compliance.sh
   ```

---

## Complete Deployment Guide

### Section 1: Pre-Deployment Verification

#### ✅ 1.1 Verify JAR is Built

```bash
ls -lh target/timezone-mcp-server-1.0.0-mule-application.jar
```

**Expected**: File exists, ~5.1 MB

**If missing**:
```bash
./deploy.sh
```

#### ✅ 1.2 Verify OAuth Configuration

Check that the HTTP request config is in the JAR:

```bash
unzip -p target/timezone-mcp-server-1.0.0-mule-application.jar timezone-mcp-server.xml | grep "anypoint-auth-config"
```

**Expected**: Should see `<http:request-config name="anypoint-auth-config"`

#### ✅ 1.3 Verify Connected App Credentials

**Connected App**: Timezone MCP OAuth Client

| Credential | Value |
|------------|-------|
| Client ID | `YOUR_CLIENT_ID` |
| Client Secret | `YOUR_CLIENT_SECRET` |
| Token Endpoint | `https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token` |

**Test token generation**:
```bash
curl -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET"
```

**Expected**: Returns `{"access_token": "eyJ...", ...}`

---

### Section 2: CloudHub Deployment

#### ✅ 2.1 Log into Anypoint Platform

1. Go to: https://anypoint.mulesoft.com
2. Log in with your credentials

#### ✅ 2.2 Navigate to Runtime Manager

1. Click **Runtime Manager** (left sidebar)
2. Find **timezone-mcp-server** in the Applications list

#### ✅ 2.3 Upload New Version

**Option A: Update existing deployment**
1. Click **timezone-mcp-server**
2. Click **Settings** tab
3. Scroll to **Application file** section
4. Click **Choose file**
5. Select: `target/timezone-mcp-server-1.0.0-mule-application.jar`
6. Click **Apply changes**

**Option B: New deployment**
1. Click **Deploy application**
2. Fill in:
   - **Application Name**: `timezone-mcp-server`
   - **Runtime version**: `4.6.0`
   - **Worker size**: MICRO (0.1 vCores)
   - **Workers**: 1
   - **Region**: us-east-2
3. Upload JAR file
4. Click **Deploy Application**

#### ✅ 2.4 Monitor Deployment

**Status check**:
1. Runtime Manager → timezone-mcp-server
2. Watch status change: `Deploying...` → `Started`
3. **Expected time**: 3-5 minutes

**If stuck >10 minutes**:
1. Click **Logs** tab
2. Check last 50 lines for errors
3. Common issues:
   - Port conflict → Stop other apps
   - XML syntax error → Rebuild JAR
   - Resource exhaustion → Stop unused apps

#### ✅ 2.5 Verify Endpoint

**URL**: `https://{your-app-name}.{region}.cloudhub.io/mcp`

**Quick test** (should return 401):
```bash
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

**Expected**: `{"error": {..., "message": "Unauthorized: Missing or invalid Bearer token"}}`

---

### Section 3: Testing

#### ✅ 3.1 Run OAuth Test Suite

```bash
./test-oauth.sh
```

**Expected output**:
```
✓ Token obtained
✓ Correctly rejected unauthenticated request
✓ Correctly rejected invalid token
✓ Successfully authenticated and got tools
✓ Tool call successful
```

#### ✅ 3.2 Run MCP Compliance Test Suite

```bash
./test-mcp-compliance.sh
```

**Expected output**:
```
Total Tests: 33
Passed: 33
Failed: 0

✓ MCP Server is fully compliant!
```

**What's tested**:
- Core MCP protocol (initialize, notifications)
- Tools discovery (tools/list)
- Tool execution (all 4 tools)
- Error handling (unknown methods, invalid tokens)
- JSON-RPC 2.0 compliance

#### ✅ 3.3 Manual Tool Testing

**Test each tool individually**:

```bash
# Get OAuth token first
TOKEN=$(curl -s -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

# Test 1: get_current_time
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_current_time","arguments":{"city":"Tokyo"}}}'

# Test 2: convert_time
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"convert_time","arguments":{"time":"15:00","from_city":"New York","to_city":"London"}}}'

# Test 3: time_difference
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"time_difference","arguments":{"city1":"New York","city2":"Tokyo"}}}'

# Test 4: list_timezones
curl -X POST https://{your-app-url}/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"list_timezones","arguments":{"region":"Asia"}}}'
```

---

## Deployment Status Checklist

Use this checklist to track your progress:

### Pre-Deployment
- [ ] JAR file built (target/timezone-mcp-server-1.0.0-mule-application.jar)
- [ ] OAuth config verified in JAR
- [ ] Connected App credentials verified
- [ ] Token generation tested

### CloudHub Deployment
- [ ] Logged into Anypoint Platform
- [ ] Uploaded new JAR version
- [ ] Deployment status: Started
- [ ] Endpoint returns 401 without auth

### Testing
- [ ] OAuth test suite passed (./test-oauth.sh)
- [ ] MCP compliance test passed (./test-mcp-compliance.sh)
- [ ] Manual tool tests successful
- [ ] All 4 tools returning correct results

---

## Troubleshooting

### Issue: Token generation fails

**Symptoms**: `curl` to token endpoint returns error

**Check**:
1. Client ID and Client Secret are correct
2. Connected App exists and is active
3. Connected App has "View Organization" scope

**Fix**: Recreate Connected App with correct scopes (see IN-APP-OAUTH-GUIDE.md)

---

### Issue: MCP server returns 401 with valid token

**Symptoms**: Test with valid OAuth token returns "Invalid or expired OAuth token"

**Possible causes**:
1. Token expired (tokens last 1 hour)
2. Anypoint Platform authentication issue
3. HTTP request config misconfigured

**Check**:
```bash
# Test if token works directly with Anypoint
curl -H "Authorization: Bearer $TOKEN" https://anypoint.mulesoft.com/accounts/api/v2/me
```

If this returns 200, the token is valid. If it returns 401, get a fresh token.

**Fix**: Get a new token and retry

---

## Documentation Reference

| Document | Purpose |
|----------|---------|
| **IN-APP-OAUTH-GUIDE.md** | OAuth implementation and Connected App setup |
| **DEPLOYMENT-CHECKLIST.md** | This file - step-by-step deployment |
| **test-oauth.sh** | OAuth functionality tests |
| **test-mcp-compliance.sh** | MCP protocol compliance tests |

---

## Success Criteria

✅ **Deployment is successful when all of the following are true**:

1. CloudHub deployment status: "Started"
2. `./test-mcp-compliance.sh` passes all 33 tests
3. Endpoint returns 401 without a token and valid results with a token
4. All 4 tools return correct results

---

## Next Steps After Deployment

1. **Register the server** in your MCP client using the CloudHub endpoint and Connected App credentials (to register in Salesforce, refer to the accompanying blog post)
2. **Monitor CloudHub logs** for usage patterns
3. **Consider enhancements**:
   - Cache token validation results (reduce latency)
   - Add more timezone tools (meeting scheduler, etc.)
   - Implement rate limiting for production
4. **Deploy to production** with a separate Connected App

---

**Last Updated**: July 1, 2026  
**Version**: 1.0.0  
**Status**: ✅ Ready for Deployment
