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

# 检查必需的配置（使用 103 的配置）
if [ -z "$ADGUARD_103_API_URL" ]; then
    echo "错误: ADGUARD_103_API_URL 未配置"
    echo "请在 scripts.conf 中配置 AdGuard Home 103 实例的信息"
    exit 1
fi

if [ -z "$ADGUARD_103_USERNAME" ] || [ -z "$ADGUARD_103_PASSWORD" ]; then
    echo "错误: ADGUARD_103_USERNAME 或 ADGUARD_103_PASSWORD 未配置"
    exit 1
fi

# 预制规则部分（固定规则，不变）
PRESET_RULES='["||gamesgo.net^","||game.moe.ms^","||265.com^","||yandex.com^","||papergaes.io^","||17yoo.cn^","||gamemonetize.com^","||gamemonetize.video^","||gamemonetize.co^","||finder.video.qq.com^","||szextshort.weixin.qq.com^","||360.cn^","||msn.cn^","||4399.com^","||18183.com^","||Y8.com^","||addictinggames.com^","||7k7k.com^","||freeonlinegames.com^","||armorgames.com^","||html5games.com^","||kongregate.com^","||17173.com^","||2436.cn^","||3199.cn^","||17yy.com^","||pogo.com^","||douying.com^","||douyin.com^","||acfun.cn^","||ixigua.com^","||shifen.aazzgames.com^","@@||jia.360.cn^$important"]'

# 追加规则部分（可以根据需要配置）
ADDITIONAL_RULES_DISABLE='["||poki.com^","||youtube.com^","||crazygames.com^","||y8.com^","||kizi.com^","||gamepix.com^","||miniclip.com^","||armorgames.com^","||friv.com^","||gamer.qq.com^","||gamer.cdn-go.cn^","||gamer.qpic.cn^","||m.gamer.qq.com^","||main.gamecenter.vivo.com.cn^","||mystery-game-tile.poki.io^","||st-onlinegame.vivo.com.cn^","||game.weixin.qq.com^","||gamematrix.qq.com^","||apps.game.qq.com^","||ams.game.qq.com^"]'
ADDITIONAL_RULES_ENABLE='[]'  # 启用时清空额外规则

# 合并规则，添加或删除追加规则
merge_rules() {
    if [ "$1" == "disable" ]; then
        # 使用 jq 将预制规则和禁用时的追加规则合并
        BODY=$(echo "$PRESET_RULES" | jq -c --argjson additional "$ADDITIONAL_RULES_DISABLE" '. + $additional')
        BODY="{\"rules\":$BODY}"
    elif [ "$1" == "enable" ]; then
        # 启用时清空额外规则
        BODY=$(echo "$PRESET_RULES" | jq -c --argjson additional "$ADDITIONAL_RULES_ENABLE" '. + $additional')
        BODY="{\"rules\":$BODY}"
    fi
}

# 发送 POST 请求的函数
send_post_request() {
    HTTP_CODE=$(curl -o /dev/null -w '%{http_code}' -X POST "$ADGUARD_103_API_URL" \
    -u "$ADGUARD_103_USERNAME:$ADGUARD_103_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/plain, */*" \
    -H "Accept-Encoding: gzip, deflate" \
    -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6" \
    -H "Connection: keep-alive" \
    -H "Host: $ADGUARD_103_HOST" \
    -H "Origin: http://$ADGUARD_103_HOST" \
    -H "Referer: http://$ADGUARD_103_HOST/" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0" \
    -d "$BODY")
    echo "HTTP Status Code: $HTTP_CODE"
}

# 根据传入参数执行 disable 或 enable
case "$1" in
    disable)
        echo "禁用规则，发送请求..."
        merge_rules "disable"
        echo "Request Body: $BODY"  # 打印请求体
        send_post_request
        ;;
    enable)
        echo "启用规则，发送请求..."
        merge_rules "enable"
        echo "Request Body: $BODY"  # 打印请求体
        send_post_request
        ;;
    *)
        echo "无效的参数：$1。请使用 disable 或 enable."
        exit 1
        ;;
esac
