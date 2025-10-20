#!/bin/bash
# 测试不同配置的脚本

set -e

echo "=== 配置测试脚本 ==="
echo ""

# 测试 1: 默认配置
echo "测试 1: 使用默认端口和日志路径"
cat > config_test1.json << 'EOF'
{
  "username": "admin",
  "password": "test123",
  "nasLimitScript": "./scripts/naslimit.sh",
  "networkLimitScript": "./scripts/netlimit.sh",
  "clashLimitScript": "./scripts/clashlimit.sh",
  "websiteLimitScripts": []
}
EOF
echo "✓ 创建 config_test1.json (使用默认值)"

# 测试 2: 自定义端口
echo ""
echo "测试 2: 自定义端口 8080"
cat > config_test2.json << 'EOF'
{
  "username": "admin",
  "password": "test123",
  "serverPort": "8080",
  "nasLimitScript": "./scripts/naslimit.sh",
  "networkLimitScript": "./scripts/netlimit.sh",
  "clashLimitScript": "./scripts/clashlimit.sh",
  "websiteLimitScripts": []
}
EOF
echo "✓ 创建 config_test2.json (端口: 8080)"

# 测试 3: 自定义日志路径
echo ""
echo "测试 3: 自定义日志路径"
cat > config_test3.json << 'EOF'
{
  "username": "admin",
  "password": "test123",
  "serverPort": "20000",
  "logFilePath": "/tmp/test_controlpanel.log",
  "nasLimitScript": "./scripts/naslimit.sh",
  "networkLimitScript": "./scripts/netlimit.sh",
  "clashLimitScript": "./scripts/clashlimit.sh",
  "websiteLimitScripts": []
}
EOF
echo "✓ 创建 config_test3.json (日志: /tmp/test_controlpanel.log)"

# 测试 4: 绝对路径
echo ""
echo "测试 4: 使用绝对路径"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cat > config_test4.json << EOF
{
  "username": "admin",
  "password": "test123",
  "serverPort": "20000",
  "logFilePath": "/tmp/test_controlpanel.log",
  "nasLimitScript": "${SCRIPT_DIR}/scripts/naslimit.sh",
  "networkLimitScript": "${SCRIPT_DIR}/scripts/netlimit.sh",
  "clashLimitScript": "${SCRIPT_DIR}/scripts/clashlimit.sh",
  "websiteLimitScripts": []
}
EOF
echo "✓ 创建 config_test4.json (使用绝对路径)"

echo ""
echo "=== 验证 JSON 格式 ==="
for config in config_test*.json; do
    if command -v jq >/dev/null 2>&1; then
        if jq empty "$config" 2>/dev/null; then
            echo "✓ $config - JSON 格式正确"
        else
            echo "✗ $config - JSON 格式错误"
        fi
    else
        if python3 -m json.tool "$config" >/dev/null 2>&1; then
            echo "✓ $config - JSON 格式正确"
        else
            echo "✗ $config - JSON 格式错误"
        fi
    fi
done

echo ""
echo "=== 测试完成 ==="
echo ""
echo "使用方法："
echo "  APP_CONFIG_PATH=config_test1.json ./controlpanel_test"
echo "  APP_CONFIG_PATH=config_test2.json ./controlpanel_test"
echo "  APP_CONFIG_PATH=config_test3.json ./controlpanel_test"
echo "  APP_CONFIG_PATH=config_test4.json ./controlpanel_test"
echo ""
echo "清理测试文件："
echo "  rm -f config_test*.json"
