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
# Verify Connected App credentials by requesting an OAuth token.
# Reads CLIENT_ID, CLIENT_SECRET, and TOKEN_ENDPOINT from ../.env
# Usage: ./scripts/verify-credentials.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load config from .env in the repo root (copy .env.example to .env and fill it in)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

CLIENT_ID="${CLIENT_ID:-YOUR_CLIENT_ID}"
CLIENT_SECRET="${CLIENT_SECRET:-YOUR_CLIENT_SECRET}"
TOKEN_ENDPOINT="${TOKEN_ENDPOINT:-https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token}"

if [ "$CLIENT_ID" = "YOUR_CLIENT_ID" ] || [ "$CLIENT_SECRET" = "YOUR_CLIENT_SECRET" ]; then
  echo -e "${RED}✗ CLIENT_ID / CLIENT_SECRET are not set.${NC}"
  echo "  Copy .env.example to .env and fill in your Connected App credentials."
  exit 1
fi

echo "Requesting a token from Anypoint Platform..."
RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
  echo -e "${GREEN}✓ Credentials valid — token obtained${NC}"
  echo "Token (first 20 chars): ${TOKEN:0:20}..."
else
  echo -e "${RED}✗ Failed to obtain a token${NC}"
  echo "Response: $RESPONSE"
  exit 1
fi
