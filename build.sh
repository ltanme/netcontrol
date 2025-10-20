#!/usr/bin/env bash
# Build script to compile the Go application for OpenWrt ARM64 on macOS

set -euo pipefail

echo "Building for OpenWrt ARM64..."

# ---- Config ----
GOOS_TARGET=linux
GOARCH_TARGET=arm64
CGO_ENABLED_TARGET=0
OUTPUT_NAME="controlpanel_openwrt_arm64"

# ---- Checks ----
if ! command -v go >/dev/null 2>&1; then
  echo "ERROR: 'go' command not found."
  echo "提示：如果你用 mise 管理 Go，先执行："
  echo "  mise use go@1.24.5   # 或 mise global go@1.24.5"
  echo "  eval \"\$(mise activate zsh)\"  # zsh"
  exit 1
fi

if [[ ! -f "main.go" ]]; then
  echo "ERROR: main.go not found in the current directory."
  echo "Please run this script from the root of your Go project."
  exit 1
fi

# ---- Clean previous build ----
echo "Cleaning up previous build (if any)..."
rm -f "${OUTPUT_NAME}"

# ---- Build ----
echo "Setting env: GOOS=${GOOS_TARGET} GOARCH=${GOARCH_TARGET} CGO_ENABLED=${CGO_ENABLED_TARGET}"
echo "Running: go build -o ${OUTPUT_NAME} -ldflags='-s -w' main.go"
GOOS="${GOOS_TARGET}" GOARCH="${GOARCH_TARGET}" CGO_ENABLED="${CGO_ENABLED_TARGET}" \
go build -o "${OUTPUT_NAME}" -ldflags="-s -w" main.go

echo
echo "=================================================================================="
echo "Build successful! Output: ${OUTPUT_NAME}"
echo "=================================================================================="
read -r -p "View deployment checklist for OpenWrt ARM64? (y/N): " yn
case "${yn:-N}" in
  y|Y)
    echo
    echo "Deployment Checklist for OpenWrt ARM64:"
    echo "1) 传输可执行文件到 OpenWrt："
    echo "   scp ${OUTPUT_NAME} root@<router-ip>:/opt/controlpanel/${OUTPUT_NAME}"
    echo "2) 传输配置文件：config.json 到同目录："
    echo "   scp config.json root@<router-ip>:/opt/controlpanel/config.json"
    echo "3) 传输静态资源目录 static/："
    echo "   scp -r static root@<router-ip>:/opt/controlpanel/static"
    echo "4) 传输脚本目录 scripts/："
    echo "   scp -r scripts root@<router-ip>:/opt/controlpanel/scripts"
    echo "5) 在 OpenWrt 上赋权："
    echo "   chmod +x /opt/controlpanel/${OUTPUT_NAME}"
    echo "6) 给所有 .sh 脚本赋权："
    echo "   chmod +x /opt/controlpanel/scripts/*.sh 2>/dev/null || true"
    echo "7) 运行："
    echo "   cd /opt/controlpanel && ./$(basename "${OUTPUT_NAME}")"
    echo "8) 确认防火墙放行端口（例如 20000）："
    echo "   uci add firewall rule; uci set firewall.@rule[-1].name='controlpanel'; \\"
    echo "   uci set firewall.@rule[-1].src='*'; uci set firewall.@rule[-1].target='ACCEPT'; \\"
    echo "   uci set firewall.@rule[-1].proto='tcp'; uci set firewall.@rule[-1].dest_port='20000'; uci commit firewall; /etc/init.d/firewall restart"
    echo
    ;;
  *)
    ;;
esac

echo "Script finished."
