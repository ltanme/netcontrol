#!/bin/sh
LOG_FILE="/root/cron_reboot_controlpanel.log"
APP_BINARY="./controlpanel_openwrt_arm64" # Go程序名
APP_DIR="/root"

echo "$(date): Attempting to start controlpanel via cron @reboot script." > "${LOG_FILE}"

# 切换到工作目录
cd "${APP_DIR}"
if [ $? -ne 0 ]; then
    echo "$(date): Failed to cd to ${APP_DIR}. Exiting." >> "${LOG_FILE}"
    exit 1
fi

# 在后台启动 Go 程序，并将其输出重定向到日志文件
echo "$(date): Starting ${APP_BINARY} in background..." >> "${LOG_FILE}"
nohup "${APP_BINARY}" >> "${LOG_FILE}" 2>&1 &
# 或者仅仅是:
# "${APP_BINARY}" >> "${LOG_FILE}" 2>&1 &

# 获取后台进程的 PID (可选，但有助于调试)
# APP_PID=$!
# echo "$(date): ${APP_BINARY} started in background with PID ${APP_PID} (hopefully)." >> "${LOG_FILE}"

# 包装脚本现在可以退出了，Go 程序应该在后台继续运行
echo "$(date): Wrapper script finished. ${APP_BINARY} should be running in background." >> "${LOG_FILE}"
exit 0