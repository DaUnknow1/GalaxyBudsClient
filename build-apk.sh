#!/bin/bash
set -e

echo "=== GalaxyBudsClient Android APK Build Script ==="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check required tools
echo -e "${YELLOW}Checking for required tools...${NC}"

# Check Java/JDK
if ! command -v java &> /dev/null; then
    echo -e "${RED}Error: Java/JDK not found. Installing JDK 21...${NC}"
    sudo apt-get update
    sudo apt-get install -y openjdk-21-jdk-headless
fi

JAVA_VERSION=$(java -version 2>&1 | head -1)
echo -e "${GREEN}✓ Java found: ${JAVA_VERSION}${NC}"

# Check .NET
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}Error: .NET SDK not found. Please install .NET SDK 10.0.103${NC}"
    exit 1
fi

DOTNET_VERSION=$(dotnet --version)
echo -e "${GREEN}✓ .NET found: ${DOTNET_VERSION}${NC}"

# Setup Android environment variables
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Android/Sdk}
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

echo -e "${YELLOW}ANDROID_HOME: ${ANDROID_HOME}${NC}"
echo -e "${YELLOW}JAVA_HOME: ${JAVA_HOME}${NC}"

# Check/Install Android SDK if not present
if [ ! -d "$ANDROID_HOME" ]; then
    echo -e "${YELLOW}Android SDK not found. Installing...${NC}"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    
    cd /tmp
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
    unzip -q cmdline-tools.zip -d cmdline-tools-unzipped
    mv cmdline-tools-unzipped/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf cmdline-tools.zip cmdline-tools-unzipped
    
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    echo -e "${YELLOW}Accepting Android SDK licenses...${NC}"
    yes | sdkmanager --licenses > /dev/null 2>&1 || true
    
    echo -e "${YELLOW}Installing Android SDK components...${NC}"
    sdkmanager "platforms;android-36" "build-tools;36.0.0" "platform-tools"
else
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    echo -e "${GREEN}✓ Android SDK found${NC}"
fi

# Install .NET Android workload if not already installed
echo -e "${YELLOW}Ensuring .NET Android workload is installed...${NC}"
dotnet workload install android

# Build parameters
BUILD_TYPE="${1:-Debug}"
NO_DEMO="${2:-false}"
OUTPUT_FORMAT="${3:-apk}"

echo -e "${YELLOW}Build Configuration:${NC}"
echo "  Configuration: $BUILD_TYPE"
echo "  Demo Version: $([ "$NO_DEMO" = "true" ] && echo "No" || echo "Yes")"
echo "  Output Format: $OUTPUT_FORMAT"

# Build the APK
echo -e "${YELLOW}Building APK...${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

dotnet publish \
    -f net10.0-android36.1 \
    -c "$BUILD_TYPE" \
    -p:AndroidPackageFormats="$OUTPUT_FORMAT" \
    -p:AndroidSdkDirectory="$ANDROID_HOME" \
    -p:DebugType=PdbOnly \
    -p:EmbedAssembliesIntoApk=true \
    -p:IsAndroid=true \
    -p:NoDemo="$NO_DEMO" \
    "$SCRIPT_DIR/GalaxyBudsClient.Android/GalaxyBudsClient.Android.csproj"

# Find and report the output APK
OUTPUT_DIR="$SCRIPT_DIR/GalaxyBudsClient.Android/bin/$BUILD_TYPE/net10.0-android36.1/publish"

if [ "$NO_DEMO" = "true" ]; then
    APK_FILE="$OUTPUT_DIR/me.timschneeberger.galaxybudsclient-Signed.apk"
else
    APK_FILE="$OUTPUT_DIR/me.timschneeberger.galaxybudsclient.demo-Signed.apk"
fi

if [ -f "$APK_FILE" ]; then
    SIZE=$(du -h "$APK_FILE" | cut -f1)
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo -e "${GREEN}APK location: $APK_FILE${NC}"
    echo -e "${GREEN}Size: $SIZE${NC}"
else
    echo -e "${RED}✗ Build failed or APK not found at expected location${NC}"
    echo -e "${YELLOW}Checking output directory: $OUTPUT_DIR${NC}"
    ls -lah "$OUTPUT_DIR" 2>/dev/null || echo "Directory not found"
    exit 1
fi
