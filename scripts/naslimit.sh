#!/bin/bash

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/scripts.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    echo "请复制 scripts.conf.example 为 scripts.conf 并配置"
    exit 1
fi

# 加载配置
source "$CONFIG_FILE"

# 检查必需的配置
if [ -z "$NAS_API_URL" ]; then
    echo "错误: NAS_API_URL 未配置"
    exit 1
fi

# 用法提示
if [ "$1" == "enable" ]; then
    VV="1"
elif [ "$1" == "disable" ]; then
    VV="0"
else
    echo "Usage: $0 enable|disable"
    exit 1
fi

URL="${NAS_API_URL}?vv=$VV"

echo "调用接口: $URL"
RESPONSE=$(curl -s "$URL")

echo "接口响应:"
echo "$RESPONSE"

# 临时文件方式解决 jq 无法处理 echo 多行问题
TMP_FILE=$(mktemp)
echo "$RESPONSE" > "$TMP_FILE"

# 如果 jq 可用，解析字段
if command -v jq >/dev/null 2>&1; then
    echo "状态: $(jq -r '.status' "$TMP_FILE")"
    echo "NFS: $(jq -r '.steps.nfs' "$TMP_FILE")"
    echo "SMB: $(jq -r '.steps.smb' "$TMP_FILE")"
    echo "Emby: $(jq -r '.steps.emby' "$TMP_FILE")"
else
    echo "未安装 jq，跳过 JSON 解析"
fi

rm -f "$TMP_FILE"