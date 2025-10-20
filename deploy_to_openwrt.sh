#!/bin/bash
# 部署脚本 - 安全地部署到 OpenWRT

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
OPENWRT_HOST="${1:-openwrt}"
OPENWRT_USER="root"
OPENWRT_DIR="/root"

echo -e "${GREEN}=== OpenWRT 控制面板部署脚本 ===${NC}"
echo ""

# 检查参数
if [ -z "$1" ]; then
    echo -e "${YELLOW}使用默认主机: openwrt${NC}"
    echo "如需指定主机: $0 192.168.1.1"
    echo ""
fi

# 检查必需文件
echo "检查必需文件..."
REQUIRED_FILES=(
    "controlpanel_openwrt_arm64"
    "config.json"
    "start_controlpanel_improved.sh"
    "install_service.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 文件不存在: $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ 必需文件检查通过${NC}"

# 检查脚本配置
echo ""
echo "检查脚本配置..."
if [ ! -f "scripts/scripts.conf" ]; then
    echo -e "${RED}错误: scripts/scripts.conf 不存在${NC}"
    echo -e "${YELLOW}请先配置脚本:${NC}"
    echo "  cd scripts"
    echo "  cp scripts.conf.example scripts.conf"
    echo "  vi scripts.conf  # 填入实际配置"
    exit 1
fi
echo -e "${GREEN}✓ 脚本配置文件存在${NC}"

# 警告：检查敏感信息
echo ""
echo -e "${YELLOW}⚠️  安全检查...${NC}"
if grep -q "your_password_here\|your_token_here\|192.168.x.x" scripts/scripts.conf; then
    echo -e "${RED}警告: scripts.conf 中包含示例值，请确认已修改为实际值${NC}"
    read -p "是否继续部署? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 确认部署
echo ""
echo "准备部署到: ${OPENWRT_USER}@${OPENWRT_HOST}:${OPENWRT_DIR}"
read -p "是否继续? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "部署已取消"
    exit 0
fi

# 开始部署
echo ""
echo -e "${GREEN}开始部署...${NC}"

# 1. 上传主程序和配置
echo ""
echo "1. 上传主程序和配置文件..."
scp controlpanel_openwrt_arm64 config.json ${OPENWRT_USER}@${OPENWRT_HOST}:${OPENWRT_DIR}/
echo -e "${GREEN}✓ 主程序上传完成${NC}"

# 2. 上传脚本目录
echo ""
echo "2. 上传脚本目录..."
scp -r scripts ${OPENWRT_USER}@${OPENWRT_HOST}:${OPENWRT_DIR}/
echo -e "${GREEN}✓ 脚本上传完成${NC}"

# 3. 上传静态文件
echo ""
echo "3. 上传静态文件..."
scp -r static ${OPENWRT_USER}@${OPENWRT_HOST}:${OPENWRT_DIR}/
echo -e "${GREEN}✓ 静态文件上传完成${NC}"

# 4. 上传启动脚本
echo ""
echo "4. 上传启动脚本..."
scp start_controlpanel_improved.sh install_service.sh ${OPENWRT_USER}@${OPENWRT_HOST}:${OPENWRT_DIR}/
echo -e "${GREEN}✓ 启动脚本上传完成${NC}"

# 5. 设置权限
echo ""
echo "5. 设置文件权限..."
ssh ${OPENWRT_USER}@${OPENWRT_HOST} << 'EOF'
cd /root
chmod +x controlpanel_openwrt_arm64
chmod +x start_controlpanel_improved.sh
chmod +x install_service.sh
chmod +x scripts/*.sh
chmod 600 config.json
chmod 600 scripts/scripts.conf
echo "权限设置完成"
EOF
echo -e "${GREEN}✓ 权限设置完成${NC}"

# 6. 验证配置
echo ""
echo "6. 验证配置..."
ssh ${OPENWRT_USER}@${OPENWRT_HOST} << 'EOF'
cd /root
echo "检查文件..."
ls -lh controlpanel_openwrt_arm64 config.json
echo ""
echo "检查脚本配置..."
if [ -f scripts/scripts.conf ]; then
    echo "✓ scripts/scripts.conf 存在"
else
    echo "✗ scripts/scripts.conf 不存在"
fi
EOF
echo -e "${GREEN}✓ 配置验证完成${NC}"

# 完成
echo ""
echo -e "${GREEN}=== 部署完成 ===${NC}"
echo ""
echo "下一步操作："
echo ""
echo "1. 安装服务（可选）："
echo "   ssh ${OPENWRT_USER}@${OPENWRT_HOST}"
echo "   cd ${OPENWRT_DIR}"
echo "   ./install_service.sh"
echo ""
echo "2. 启动服务："
echo "   /etc/init.d/controlpanel start"
echo ""
echo "3. 或手动启动："
echo "   ./start_controlpanel_improved.sh start"
echo ""
echo "4. 查看日志："
echo "   tail -f /tmp/controlpanel_openwrt_arm64.log"
echo ""
echo "5. 访问控制面板："
echo "   http://${OPENWRT_HOST}:20000"
echo ""
