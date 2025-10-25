#!/bin/sh
# 阻止手机&平板上网脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/scripts.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    echo "请复制 scripts.conf.example 为 scripts.conf 并配置"
    exit 1
fi

# 加载配置
. "$CONFIG_FILE"

# 检查必需的配置
if [ -z "$BAN_MOBILE_MAC_LIST" ]; then
    echo "错误: BAN_MOBILE_MAC_LIST 未配置"
    exit 1
fi

# 配置需要操作的MAC地址，多个地址之间以空格分隔
MAC_LIST="$BAN_MOBILE_MAC_LIST"

manage_mac() {
    for mac in $MAC_LIST; do
        case "$1" in
            disable)
                # disable = 阻止上网
                # 检查是否已经存在DROP规则，如果不存在则添加规则
                iptables -C FORWARD -m mac --mac-source "$mac" -j DROP 2>/dev/null
                if [ $? -ne 0 ]; then
                    iptables -I FORWARD -m mac --mac-source "$mac" -j DROP
                    logger -p info -t "ban_mobile" "已阻止手机&平板 MAC地址 $mac 上网"
                    echo "已阻止手机&平板 MAC地址 $mac 上网"
                else
                    logger -p info -t "ban_mobile" "手机&平板 MAC地址 $mac 已经处于阻止状态"
                    echo "手机&平板 MAC地址 $mac 已经处于阻止状态"
                fi
                ;;
            enable)
                # enable = 允许上网
                # 检查是否存在DROP规则，如果存在则删除规则
                iptables -C FORWARD -m mac --mac-source "$mac" -j DROP 2>/dev/null
                if [ $? -eq 0 ]; then
                    iptables -D FORWARD -m mac --mac-source "$mac" -j DROP
                    logger -p info -t "ban_mobile" "已允许手机&平板 MAC地址 $mac 上网"
                    echo "已允许手机&平板 MAC地址 $mac 上网"
                else
                    logger -p info -t "ban_mobile" "手机&平板 MAC地址 $mac 当前未被阻止"
                    echo "手机&平板 MAC地址 $mac 当前未被阻止"
                fi
                ;;
            *)
                logger -p err -t "ban_mobile" "不支持的参数: $1。请使用 disable 或 enable."
                echo "用法: $0 enable|disable"
                echo "  enable  - 允许手机&平板上网"
                echo "  disable - 阻止手机&平板上网"
                exit 1
                ;;
        esac
    done
}

# 根据传入参数调用对应功能
manage_mac "$1"
