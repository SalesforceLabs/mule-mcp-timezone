#!/bin/bash
#
# Copyright (c) 2026, Salesforce, Inc.
# SPDX-License-Identifier: Apache-2
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Quick smoke test for the deployed Timezone MCP Server.
# Calls the endpoint with no token and expects a 401 Unauthorized.
# Usage: ./scripts/smoke-test.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration — load MCP_URL from .env in the repo root (copy .env.example to .env and fill it in)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

MCP_URL="${MCP_URL:-https://YOUR-APP-URL/mcp}"

echo "Smoke test (no token → expect 401): $MCP_URL"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "401" ] || echo "$BODY" | grep -q "Unauthorized"; then
  echo -e "${GREEN}✓ Correctly rejected unauthenticated request (HTTP $HTTP_CODE)${NC}"
  echo "$BODY"
  exit 0
else
  echo -e "${RED}✗ Expected 401 Unauthorized, got HTTP $HTTP_CODE${NC}"
  echo "$BODY"
  exit 1
fi
