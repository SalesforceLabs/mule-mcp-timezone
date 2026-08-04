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
# This script packages the Mule application for CloudHub deployment.
#
# Mule 4.9 must be built with Java 17. If JAVA_HOME isn't already a Java 17
# JDK, this script tries to locate one so the build uses the right version
# (Maven resolves its JDK from JAVA_HOME, which may differ from `java` on PATH).

set -e

# Run from the repo root (this script lives in scripts/) so Maven finds pom.xml.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Ensure the build runs on Java 17.
# On Windows, run this script under Git Bash or WSL (paths look like /c/Program Files/...).
if [ -z "$JAVA_HOME" ] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"17'; then
  if [ -x /usr/libexec/java_home ]; then
    # macOS
    JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null)" || true
  elif [ -d /usr/lib/jvm/java-17-openjdk ]; then
    # Linux (common path)
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk
  else
    # Windows (Git Bash / WSL) — pick the highest Temurin/OpenJDK 17 install
    for base in "/c/Program Files/Eclipse Adoptium" "/c/Program Files/Java" "/c/Program Files/Microsoft"; do
      candidate="$(ls -d "$base"/*jdk-17* 2>/dev/null | sort | tail -1)"
      if [ -n "$candidate" ]; then
        JAVA_HOME="$candidate"
        break
      fi
    done
  fi
  export JAVA_HOME
fi

if [ -z "$JAVA_HOME" ] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"17'; then
  echo "ERROR: Java 17 is required to build, but it could not be found."
  echo ""
  echo "Install it, then re-run this script:"
  echo "   macOS:    brew install openjdk@17"
  echo "   Linux:    sudo apt-get install openjdk-17-jdk   (or your distro's equivalent)"
  echo "   Windows:  winget install EclipseAdoptium.Temurin.17.JDK   (run this script under Git Bash or WSL)"
  echo ""
  echo "If Java 17 is already installed, point JAVA_HOME at it, e.g.:"
  echo "   macOS:    export JAVA_HOME=\$(/usr/libexec/java_home -v 17)"
  echo "   Linux:    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk"
  echo "   Windows:  export JAVA_HOME=\"/c/Program Files/Eclipse Adoptium/jdk-17\"   (Git Bash / WSL)"
  exit 1
fi

echo "Using Java 17 at: $JAVA_HOME"
echo ""
echo "Building Timezone MCP Server..."
mvn clean package

echo ""
echo "Build complete!"
echo ""
echo "Deployable JAR created:"
echo "   target/timezone-mcp-server-1.0.0-mule-application.jar"
echo ""
echo "Next steps: follow the Deployment Guide in README.md to deploy and test."
echo ""
