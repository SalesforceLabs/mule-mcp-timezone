#!/bin/bash

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
