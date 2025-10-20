#!/bin/bash
# 本地测试脚本 - 在 macOS 上测试程序功能

set -e

echo "Building for local testing (macOS)..."
go build -o controlpanel_test main.go

echo ""
echo "Starting test server..."
echo "Press Ctrl+C to stop"
echo ""
echo "Access the control panel at: http://localhost:20000"
echo "Username: admin"
echo "Password: adm"
echo ""
echo "Logs will be written to: /tmp/controlpanel_openwrt_arm64.log"
echo ""

./controlpanel_test
