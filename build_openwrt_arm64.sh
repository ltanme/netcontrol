#!/bin/bash
# Shell script to build the Go application for OpenWrt ARM64

set -e

echo "Building for OpenWrt ARM64..."

# Set Go environment variables for cross-compilation
export GOOS=linux
export GOARCH=arm64
export CGO_ENABLED=0

# Define the output binary name
OUTPUT_NAME="controlpanel_openwrt_arm64"

# Check if main.go exists
if [ ! -f "main.go" ]; then
    echo "ERROR: main.go not found in the current directory."
    echo "Please run this script from the root of your Go project."
    exit 1
fi

echo "Cleaning up previous build (if any)..."
rm -f "${OUTPUT_NAME}"

# Build the application
echo "Running Go build command..."
go build -o "${OUTPUT_NAME}" -ldflags="-s -w" main.go

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "  Build successful!"
    echo "  Output: ${OUTPUT_NAME}"
    echo "=========================================="
    echo ""
    echo "Deployment Checklist for OpenWrt ARM64:"
    echo "1. Transfer files to OpenWrt device:"
    echo "   scp ${OUTPUT_NAME} config.json root@openwrt:/root/"
    echo "   scp -r scripts static root@openwrt:/root/"
    echo "   scp start_controlpanel_improved.sh install_service.sh root@openwrt:/root/"
    echo ""
    echo "2. On OpenWrt device, install the service:"
    echo "   ssh root@openwrt"
    echo "   cd /root"
    echo "   chmod +x install_service.sh"
    echo "   ./install_service.sh"
    echo ""
    echo "3. Start the service:"
    echo "   /etc/init.d/controlpanel start"
    echo ""
    echo "4. View logs:"
    echo "   tail -f /tmp/controlpanel_openwrt_arm64.log"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "  ERROR: Go build failed."
    echo "=========================================="
    exit 1
fi
