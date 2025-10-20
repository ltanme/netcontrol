#!/bin/sh
# 在 OpenWRT 上安装控制面板服务

APP_NAME="controlpanel"
APP_DIR="/root"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing ${APP_NAME} service on OpenWRT..."

# 复制启动脚本
cp "${SCRIPT_DIR}/start_controlpanel_improved.sh" "${APP_DIR}/"
chmod +x "${APP_DIR}/start_controlpanel_improved.sh"

# 创建 init.d 脚本
cat > /etc/init.d/${APP_NAME} << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG="/root/start_controlpanel_improved.sh"

start_service() {
    procd_open_instance
    procd_set_param command ${PROG} monitor
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    ${PROG} stop
}

restart() {
    ${PROG} restart
}

status() {
    ${PROG} status
}
EOF

chmod +x /etc/init.d/${APP_NAME}

# 启用服务
/etc/init.d/${APP_NAME} enable

echo "Service installed successfully!"
echo ""
echo "Usage:"
echo "  /etc/init.d/${APP_NAME} start   - Start the service"
echo "  /etc/init.d/${APP_NAME} stop    - Stop the service"
echo "  /etc/init.d/${APP_NAME} restart - Restart the service"
echo "  /etc/init.d/${APP_NAME} status  - Check service status"
echo ""
echo "To start now: /etc/init.d/${APP_NAME} start"
