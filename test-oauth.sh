#!/bin/bash
# Test OAuth 2.0 Validation for Timezone MCP Server
# Usage: ./test-oauth.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLIENT_ID="${CLIENT_ID:-YOUR_CLIENT_ID}"
CLIENT_SECRET="${CLIENT_SECRET:-YOUR_CLIENT_SECRET}"
TOKEN_ENDPOINT="${TOKEN_ENDPOINT:-https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token}"
# Set MCP_URL to your deployed CloudHub endpoint, e.g. https://your-app.region.cloudhub.io/mcp
MCP_URL="${MCP_URL:-https://YOUR-APP-URL/mcp}"

echo "======================================"
echo "Timezone MCP Server OAuth Test Suite"
echo "======================================"
echo ""

# Test 1: Get OAuth Token
echo -e "${YELLOW}Test 1: Get OAuth Token${NC}"
echo "Requesting token from Anypoint Platform..."
TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}✗ Failed to get token${NC}"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Token obtained${NC}"
echo "Token (first 20 chars): ${TOKEN:0:20}..."
echo ""

# Test 2: Call MCP without token (should fail)
echo -e "${YELLOW}Test 2: Call MCP without token (should return 401)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "401" ] || echo "$BODY" | grep -q "Unauthorized"; then
  echo -e "${GREEN}✓ Correctly rejected unauthenticated request${NC}"
else
  echo -e "${RED}✗ Expected 401, got HTTP $HTTP_CODE${NC}"
  echo "Response: $BODY"
fi
echo ""

# Test 3: Call MCP with invalid token (should fail)
echo -e "${YELLOW}Test 3: Call MCP with invalid token (should return 401)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer fake-invalid-token-12345" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "401" ] || echo "$BODY" | grep -q "Unauthorized"; then
  echo -e "${GREEN}✓ Correctly rejected invalid token${NC}"
else
  echo -e "${RED}✗ Expected 401, got HTTP $HTTP_CODE${NC}"
  echo "Response: $BODY"
fi
echo ""

# Test 4: Call MCP with valid token (should succeed)
echo -e "${YELLOW}Test 4: Call MCP with valid token (should return 4 tools)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "get_current_time"; then
  echo -e "${GREEN}✓ Successfully authenticated and got tools${NC}"
  TOOL_COUNT=$(echo "$BODY" | grep -o '"name":' | wc -l | tr -d ' ')
  echo "Tools discovered: $TOOL_COUNT"
  echo "$BODY" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | sed 's/^/  - /'
else
  echo -e "${RED}✗ Expected 200 with tools, got HTTP $HTTP_CODE${NC}"
  echo "Response: $BODY"
fi
echo ""

# Test 5: Call a specific tool
echo -e "${YELLOW}Test 5: Call get_current_time tool for Tokyo${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$MCP_URL" \
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
  }')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "Tokyo"; then
  echo -e "${GREEN}✓ Tool call successful${NC}"
  echo "Response:"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
else
  echo -e "${RED}✗ Tool call failed, HTTP $HTTP_CODE${NC}"
  echo "Response: $BODY"
fi
echo ""

# Summary
echo "======================================"
echo -e "${GREEN}Test Suite Complete${NC}"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Register this MCP server with your MCP client (e.g. Salesforce)"
echo "2. Use these values:"
echo "   URL: $MCP_URL"
echo "   Token Endpoint: $TOKEN_ENDPOINT"
echo "   Client ID: $CLIENT_ID"
echo "   Client Secret: $CLIENT_SECRET"
echo ""
echo "   (To register in Salesforce, refer to the accompanying blog post.)"
echo "4. Test: 'What time is it in London?'"
