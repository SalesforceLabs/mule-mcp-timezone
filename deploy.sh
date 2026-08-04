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

# Quick Deploy Script for Timezone MCP Server
# This script packages the Mule application for CloudHub deployment

set -e

echo "Building Timezone MCP Server..."
mvn clean package

echo ""
echo "Build complete!"
echo ""
echo "Deployable JAR created:"
echo "   target/timezone-mcp-server-1.0.0-mule-application.jar"
echo ""
echo "Next steps:"
echo ""
echo "1. Log into Anypoint Platform:"
echo "   https://anypoint.mulesoft.com"
echo ""
echo "2. Navigate to Runtime Manager > Deploy Application"
echo ""
echo "3. Upload the JAR file above"
echo ""
echo "4. Configure deployment:"
echo "   - Application Name: timezone-mcp-server (or unique name)"
echo "   - Runtime: 4.6.0"
echo "   - Worker Size: MICRO (0.1 vCores)"
echo "   - Region: us-east-2 (or preferred)"
echo ""
echo "5. After deployment, your MCP server will be at:"
echo "   https://{your-app-name}.{region}.cloudhub.io/mcp"
echo ""
echo "See DEPLOYMENT-CHECKLIST.md for complete setup instructions"
echo ""
