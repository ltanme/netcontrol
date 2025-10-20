#!/bin/sh
# 改进的控制面板启动脚本 - 支持自动重启和健康检查

APP_NAME="controlpanel_openwrt_arm64"
APP_DIR="/root"
APP_BINARY="${APP_DIR}/${APP_NAME}"
PID_FILE="/var/run/${APP_NAME}.pid"
LOG_FILE="/tmp/controlpanel_startup.log"
MAX_RESTART_COUNT=5
RESTART_INTERVAL=10

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_FILE}"
}

# 检查进程是否运行
is_running() {
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 停止进程
stop_app() {
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        log_msg "Stopping ${APP_NAME} (PID: ${PID})..."
        kill -TERM "${PID}" 2>/dev/null
        
        # 等待进程退出
        for i in 1 2 3 4 5; do
            if ! kill -0 "${PID}" 2>/dev/null; then
                log_msg "${APP_NAME} stopped successfully"
                rm -f "${PID_FILE}"
                return 0
            fi
            sleep 1
        done
        
        # 强制杀死
        log_msg "Force killing ${APP_NAME}..."
        kill -9 "${PID}" 2>/dev/null
        rm -f "${PID_FILE}"
    fi
    return 0
}

# 启动进程
start_app() {
    if is_running; then
        log_msg "${APP_NAME} is already running"
        return 0
    fi
    
    log_msg "Starting ${APP_NAME}..."
    
    # 切换到工作目录
    cd "${APP_DIR}" || {
        log_msg "ERROR: Failed to cd to ${APP_DIR}"
        return 1
    }
    
    # 检查可执行文件
    if [ ! -x "${APP_BINARY}" ]; then
        log_msg "ERROR: ${APP_BINARY} not found or not executable"
        return 1
    fi
    
    # 启动应用
    nohup "${APP_BINARY}" >/dev/null 2>&1 &
    APP_PID=$!
    
    # 等待一下确认启动成功
    sleep 2
    
    if kill -0 "${APP_PID}" 2>/dev/null; then
        echo "${APP_PID}" > "${PID_FILE}"
        log_msg "${APP_NAME} started successfully (PID: ${APP_PID})"
        return 0
    else
        log_msg "ERROR: ${APP_NAME} failed to start"
        return 1
    fi
}

# 重启进程
restart_app() {
    log_msg "Restarting ${APP_NAME}..."
    stop_app
    sleep 2
    start_app
}

# 健康检查
health_check() {
    # 检查进程是否存在
    if ! is_running; then
        log_msg "WARN: ${APP_NAME} is not running"
        return 1
    fi
    
    # 检查端口是否监听
    if command -v netstat >/dev/null 2>&1; then
        if ! netstat -tuln | grep -q ":20000 "; then
            log_msg "WARN: Port 20000 is not listening"
            return 1
        fi
    fi
    
    return 0
}

# 主逻辑
case "$1" in
    start)
        start_app
        ;;
    stop)
        stop_app
        ;;
    restart)
        restart_app
        ;;
    status)
        if is_running; then
            PID=$(cat "${PID_FILE}")
            log_msg "${APP_NAME} is running (PID: ${PID})"
            exit 0
        else
            log_msg "${APP_NAME} is not running"
            exit 1
        fi
        ;;
    health)
        if health_check; then
            log_msg "${APP_NAME} health check passed"
            exit 0
        else
            log_msg "${APP_NAME} health check failed"
            exit 1
        fi
        ;;
    monitor)
        # 监控模式 - 自动重启
        log_msg "Starting monitor mode..."
        RESTART_COUNT=0
        
        while true; do
            if ! health_check; then
                RESTART_COUNT=$((RESTART_COUNT + 1))
                log_msg "Health check failed (${RESTART_COUNT}/${MAX_RESTART_COUNT})"
                
                if [ ${RESTART_COUNT} -ge ${MAX_RESTART_COUNT} ]; then
                    log_msg "ERROR: Max restart count reached, giving up"
                    exit 1
                fi
                
                restart_app
                sleep ${RESTART_INTERVAL}
            else
                RESTART_COUNT=0
                sleep 30
            fi
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|health|monitor}"
        exit 1
        ;;
esac

exit $?
