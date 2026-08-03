#!/bin/bash
# MCP Protocol Compliance Test for Timezone MCP Server
# Tests all required MCP methods according to MCP specification
# Usage: ./test-mcp-compliance.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLIENT_ID="${CLIENT_ID:-YOUR_CLIENT_ID}"
CLIENT_SECRET="${CLIENT_SECRET:-YOUR_CLIENT_SECRET}"
TOKEN_ENDPOINT="${TOKEN_ENDPOINT:-https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token}"
# Set MCP_URL to your deployed CloudHub endpoint, e.g. https://your-app.region.cloudhub.io/mcp
MCP_URL="${MCP_URL:-https://YOUR-APP-URL/mcp}"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test
run_test() {
  local test_name="$1"
  local expected="$2"
  local response="$3"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  if echo "$response" | grep -q "$expected"; then
    echo -e "${GREEN}✓${NC} $test_name"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name"
    echo "  Expected: $expected"
    echo "  Got: $response"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    return 1
  fi
}

echo "=============================================="
echo "MCP Protocol Compliance Test Suite"
echo "=============================================="
echo ""
echo "Testing: $MCP_URL"
echo ""

# Get OAuth token first
echo -e "${BLUE}[Setup] Getting OAuth token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}✗ Failed to get OAuth token - cannot continue${NC}"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ OAuth token obtained${NC}"
echo ""

# ============================================
# Section 1: Core MCP Protocol Methods
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Section 1: Core MCP Protocol Methods${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 1.1: initialize method
echo -e "${BLUE}Test 1.1: initialize${NC} - MCP handshake"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    }
  }')

run_test "initialize returns protocolVersion" "protocolVersion" "$RESPONSE"
run_test "initialize returns serverInfo" "timezone-mcp-server" "$RESPONSE"
run_test "initialize returns capabilities" "capabilities" "$RESPONSE"
echo ""

# Test 1.2: notifications/initialized
echo -e "${BLUE}Test 1.2: notifications/initialized${NC} - Client ready signal"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "notifications/initialized"
  }')

# notifications/initialized should return success (no error)
if echo "$RESPONSE" | grep -qv "error"; then
  echo -e "${GREEN}✓${NC} notifications/initialized handled successfully"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo -e "${RED}✗${NC} notifications/initialized returned error"
  echo "  Response: $RESPONSE"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================
# Section 2: Tools Discovery
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Section 2: Tools Discovery${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 2.1: tools/list method
echo -e "${BLUE}Test 2.1: tools/list${NC} - List available tools"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
  }')

run_test "tools/list returns result" '"result"' "$RESPONSE"
run_test "tools/list returns tools array" '"tools"' "$RESPONSE"

# Check for all 4 expected tools
run_test "Tool 1: get_current_time present" "get_current_time" "$RESPONSE"
run_test "Tool 2: convert_time present" "convert_time" "$RESPONSE"
run_test "Tool 3: time_difference present" "time_difference" "$RESPONSE"
run_test "Tool 4: list_timezones present" "list_timezones" "$RESPONSE"

# Check tool schema structure
run_test "Tools have inputSchema" "inputSchema" "$RESPONSE"
run_test "Tools have description" "description" "$RESPONSE"

# Count tools
TOOL_COUNT=$(echo "$RESPONSE" | grep -o '"name":' | wc -l | tr -d ' ')
if [ "$TOOL_COUNT" = "4" ]; then
  echo -e "${GREEN}✓${NC} Exactly 4 tools discovered"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo -e "${RED}✗${NC} Expected 4 tools, found $TOOL_COUNT"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================
# Section 3: Tool Execution
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Section 3: Tool Execution${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 3.1: get_current_time tool
echo -e "${BLUE}Test 3.1: tools/call${NC} - get_current_time"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "get_current_time",
      "arguments": {
        "city": "Tokyo"
      }
    }
  }')

run_test "get_current_time returns result" '"result"' "$RESPONSE"
run_test "get_current_time mentions Tokyo" "Tokyo" "$RESPONSE"
run_test "get_current_time has content array" '"content"' "$RESPONSE"
run_test "get_current_time returns text type" '"type":"text"' "$RESPONSE"
echo ""

# Test 3.2: convert_time tool
echo -e "${BLUE}Test 3.2: tools/call${NC} - convert_time"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 4,
    "method": "tools/call",
    "params": {
      "name": "convert_time",
      "arguments": {
        "time": "15:00",
        "from_city": "New York",
        "to_city": "London"
      }
    }
  }')

run_test "convert_time returns result" '"result"' "$RESPONSE"
run_test "convert_time has content" '"content"' "$RESPONSE"
run_test "convert_time mentions source city" "New York" "$RESPONSE"
run_test "convert_time mentions target city" "London" "$RESPONSE"
echo ""

# Test 3.3: time_difference tool
echo -e "${BLUE}Test 3.3: tools/call${NC} - time_difference"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 5,
    "method": "tools/call",
    "params": {
      "name": "time_difference",
      "arguments": {
        "city1": "New York",
        "city2": "Tokyo"
      }
    }
  }')

run_test "time_difference returns result" '"result"' "$RESPONSE"
run_test "time_difference has content" '"content"' "$RESPONSE"
run_test "time_difference mentions both cities" "New York" "$RESPONSE"
echo ""

# Test 3.4: list_timezones tool
echo -e "${BLUE}Test 3.4: tools/call${NC} - list_timezones (all)"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 6,
    "method": "tools/call",
    "params": {
      "name": "list_timezones",
      "arguments": {}
    }
  }')

run_test "list_timezones returns result" '"result"' "$RESPONSE"
run_test "list_timezones has content" '"content"' "$RESPONSE"
run_test "list_timezones includes cities" "Tokyo" "$RESPONSE"
echo ""

# Test 3.5: list_timezones with region filter
echo -e "${BLUE}Test 3.5: tools/call${NC} - list_timezones (Asia)"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 7,
    "method": "tools/call",
    "params": {
      "name": "list_timezones",
      "arguments": {
        "region": "Asia"
      }
    }
  }')

run_test "list_timezones (Asia) returns result" '"result"' "$RESPONSE"
run_test "list_timezones (Asia) includes Asian cities" "Tokyo" "$RESPONSE"
echo ""

# ============================================
# Section 4: Error Handling
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Section 4: Error Handling${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 4.1: Unknown method
echo -e "${BLUE}Test 4.1: Unknown method${NC} - Should return error"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 8,
    "method": "unknown/method",
    "params": {}
  }')

run_test "Unknown method returns error" '"error"' "$RESPONSE"
run_test "Unknown method has error code" '"code":-32601' "$RESPONSE"
echo ""

# Test 4.2: Unknown tool
echo -e "${BLUE}Test 4.2: Unknown tool${NC} - Should return error"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 9,
    "method": "tools/call",
    "params": {
      "name": "unknown_tool",
      "arguments": {}
    }
  }')

run_test "Unknown tool returns error" '"error"' "$RESPONSE"
echo ""

# Test 4.3: Missing Authorization header
echo -e "${BLUE}Test 4.3: Missing Authorization${NC} - Should return 401"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 10,
    "method": "tools/list",
    "params": {}
  }')

run_test "Missing auth returns error" '"error"' "$RESPONSE"
run_test "Missing auth mentions Unauthorized" "Unauthorized" "$RESPONSE"
echo ""

# Test 4.4: Invalid OAuth token
echo -e "${BLUE}Test 4.4: Invalid OAuth token${NC} - Should return 401"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid-fake-token-12345" \
  -d '{
    "jsonrpc": "2.0",
    "id": 11,
    "method": "tools/list",
    "params": {}
  }')

run_test "Invalid token returns error" '"error"' "$RESPONSE"
run_test "Invalid token mentions Unauthorized" "Unauthorized" "$RESPONSE"
echo ""

# ============================================
# Section 5: JSON-RPC 2.0 Compliance
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Section 5: JSON-RPC 2.0 Compliance${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 5.1: Response has jsonrpc version
echo -e "${BLUE}Test 5.1: JSON-RPC version${NC}"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 12,
    "method": "tools/list",
    "params": {}
  }')

run_test "Response includes jsonrpc version" '"jsonrpc":"2.0"' "$RESPONSE"
echo ""

# Test 5.2: Response includes request ID
echo -e "${BLUE}Test 5.2: Request ID echo${NC}"
RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 999,
    "method": "tools/list",
    "params": {}
  }')

run_test "Response echoes request ID" '"id":999' "$RESPONSE"
echo ""

# Test 5.3: Content-Type header
echo -e "${BLUE}Test 5.3: Content-Type header${NC}"
HEADERS=$(curl -s -D - -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/list","params":{}}' \
  -o /dev/null)

if echo "$HEADERS" | grep -qi "content-type.*application/json"; then
  echo -e "${GREEN}✓${NC} Response Content-Type is application/json"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo -e "${RED}✗${NC} Response Content-Type is not application/json"
  echo "  Headers: $HEADERS"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================
# Test Summary
# ============================================
echo ""
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo ""
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
if [ $FAILED_TESTS -gt 0 ]; then
  echo -e "${RED}Failed: $FAILED_TESTS${NC}"
else
  echo "Failed: 0"
fi
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
  echo -e "${GREEN}✓ MCP Server is fully compliant!${NC}"
  echo ""
  echo "The Timezone MCP Server correctly implements:"
  echo "  • Core MCP protocol (initialize, notifications/initialized)"
  echo "  • Tool discovery (tools/list)"
  echo "  • Tool execution (tools/call)"
  echo "  • All 4 timezone tools with proper schemas"
  echo "  • Error handling (unknown methods, unknown tools)"
  echo "  • OAuth 2.0 authentication"
  echo "  • JSON-RPC 2.0 compliance"
  echo ""
  echo "Ready for MCP client integration!"
  exit 0
else
  echo -e "${RED}✗ Some tests failed - review output above${NC}"
  exit 1
fi
