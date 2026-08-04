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
# Verify the built JAR exists and contains the OAuth request config.
# Run after ./scripts/deploy.sh
# Usage: ./scripts/verify-build.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Run from the repo root (this script lives in scripts/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

JAR="target/timezone-mcp-server-1.0.0-mule-application.jar"

# Check 1: JAR exists
if [ -f "$JAR" ]; then
  echo -e "${GREEN}✓ JAR built${NC}: $JAR"
else
  echo -e "${RED}✗ JAR not found:${NC} $JAR"
  echo "  Run ./scripts/deploy.sh first."
  exit 1
fi

# Check 2: OAuth request config is present in the packaged app
if unzip -p "$JAR" timezone-mcp-server.xml 2>/dev/null | grep -q "anypoint-auth-config"; then
  echo -e "${GREEN}✓ OAuth config present${NC} (http:request-config name=\"anypoint-auth-config\")"
else
  echo -e "${RED}✗ OAuth config missing${NC} — 'anypoint-auth-config' not found in the packaged app."
  exit 1
fi

echo ""
echo -e "${GREEN}Build verified.${NC}"
