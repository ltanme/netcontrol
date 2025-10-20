#!/bin/bash
# switch_openclash_mode.sh

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
if [ -z "$CLASH_API_URL" ] || [ -z "$CLASH_API_TOKEN" ] || [ -z "$CLASH_API_HOST" ]; then
    echo "错误: Clash 配置不完整"
    exit 1
fi

# 根据参数决定模式
if [ "$1" == "enable" ]; then
    MODE="Rule"
elif [ "$1" == "disable" ]; then
    MODE="Direct"
else
    echo "Usage: $0 enable|disable"
    exit 1
fi

# 生成 JSON 数据（单行输出），例如 {"mode":"Rule"} 或 {"mode":"Direct"}
JSON_PAYLOAD=$(echo '{}' | jq -c --arg mode "$MODE" '.mode = $mode')

# 目标 URL
URL="$CLASH_API_URL"

# 构造完整的 curl 命令（全部参数在一行）
CURL_CMD="curl -X PATCH \"$URL\" \
-H \"Accept: application/json, text/plain, */*\" \
-H \"Accept-Encoding: gzip, deflate\" \
-H \"Accept-Language: en,zh-CN;q=0.9,zh;q=0.8,en-GB;q=0.7,en-US;q=0.6\" \
-H \"Authorization: Bearer $CLASH_API_TOKEN\" \
-H \"Connection: keep-alive\" \
-H \"Content-Type: application/json\" \
-H \"Host: $CLASH_API_HOST\" \
-H \"Origin: http://$CLASH_API_HOST\" \
-H \"Referer: http://$CLASH_API_HOST/ui/dashboard/\" \
-H \"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0\" \
-d '$JSON_PAYLOAD' -w \"\\nHTTP_CODE:%{http_code}\""

# 打印完整的 curl 命令
echo "Executing command:"
echo "$CURL_CMD"

# 执行 curl 请求并捕获输出（跟随重定向可选，根据实际情况可加 -L）
OUTPUT=$(eval "$CURL_CMD")
echo "$OUTPUT"