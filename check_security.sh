#!/bin/bash
# 安全检查脚本 - 检查是否有敏感信息泄漏

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== 安全检查 ===${NC}"
echo ""

ISSUES_FOUND=0

# 1. 检查 Git 状态
echo "1. 检查 Git 忽略配置..."
if git check-ignore -q config.json; then
    echo -e "${GREEN}✓ config.json 已被忽略${NC}"
else
    echo -e "${RED}✗ config.json 未被忽略 - 可能泄漏密码！${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if git check-ignore -q scripts/scripts.conf; then
    echo -e "${GREEN}✓ scripts/scripts.conf 已被忽略${NC}"
else
    echo -e "${RED}✗ scripts/scripts.conf 未被忽略 - 可能泄漏敏感信息！${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 2. 检查脚本中是否有硬编码的敏感信息
echo ""
echo "2. 检查脚本中的硬编码信息..."

# 检查 IP 地址
if grep -r "192\.168\.[0-9]\+\.[0-9]\+" scripts/*.sh 2>/dev/null | grep -v "scripts.conf" | grep -v "#"; then
    echo -e "${RED}✗ 发现硬编码的 IP 地址${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ 脚本中无硬编码 IP 地址${NC}"
fi

# 检查密码模式
if grep -r "PASSWORD=.*[^$]" scripts/*.sh 2>/dev/null | grep -v "scripts.conf" | grep -v "ADGUARD_PASSWORD" | grep -v "#"; then
    echo -e "${RED}✗ 发现硬编码的密码${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ 脚本中无硬编码密码${NC}"
fi

# 检查 Token
if grep -r "Bearer [A-Za-z0-9]\{6,\}" scripts/*.sh 2>/dev/null | grep -v "scripts.conf" | grep -v "CLASH_API_TOKEN" | grep -v "#"; then
    echo -e "${RED}✗ 发现硬编码的 Token${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ 脚本中无硬编码 Token${NC}"
fi

# 3. 检查配置文件是否存在
echo ""
echo "3. 检查配置文件..."
if [ -f "scripts/scripts.conf" ]; then
    echo -e "${GREEN}✓ scripts/scripts.conf 存在${NC}"
    
    # 检查是否还是示例值
    if grep -q "your_password_here\|your_token_here\|192.168.x.x" scripts/scripts.conf; then
        echo -e "${YELLOW}⚠️  scripts.conf 包含示例值，请确认已修改${NC}"
    else
        echo -e "${GREEN}✓ scripts.conf 已配置实际值${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  scripts/scripts.conf 不存在，需要从模板创建${NC}"
fi

if [ -f "scripts/scripts.conf.example" ]; then
    echo -e "${GREEN}✓ scripts/scripts.conf.example 存在${NC}"
else
    echo -e "${RED}✗ scripts/scripts.conf.example 不存在${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 4. 检查文件权限
echo ""
echo "4. 检查文件权限..."
if [ -f "config.json" ]; then
    PERMS=$(stat -f "%A" config.json 2>/dev/null || stat -c "%a" config.json 2>/dev/null)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        echo -e "${GREEN}✓ config.json 权限正确 ($PERMS)${NC}"
    else
        echo -e "${YELLOW}⚠️  config.json 权限为 $PERMS，建议设置为 600${NC}"
        echo "   运行: chmod 600 config.json"
    fi
fi

if [ -f "scripts/scripts.conf" ]; then
    PERMS=$(stat -f "%A" scripts/scripts.conf 2>/dev/null || stat -c "%a" scripts/scripts.conf 2>/dev/null)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        echo -e "${GREEN}✓ scripts/scripts.conf 权限正确 ($PERMS)${NC}"
    else
        echo -e "${YELLOW}⚠️  scripts/scripts.conf 权限为 $PERMS，建议设置为 600${NC}"
        echo "   运行: chmod 600 scripts/scripts.conf"
    fi
fi

# 5. 检查 Git 暂存区
echo ""
echo "5. 检查 Git 暂存区..."
if git rev-parse --git-dir > /dev/null 2>&1; then
    if git diff --cached --name-only | grep -q "config.json\|scripts/scripts.conf"; then
        echo -e "${RED}✗ 敏感文件在暂存区中！${NC}"
        echo "   运行: git reset HEAD config.json scripts/scripts.conf"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}✓ 暂存区中无敏感文件${NC}"
    fi
fi

# 总结
echo ""
echo -e "${GREEN}=== 检查完成 ===${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ 未发现安全问题${NC}"
    exit 0
else
    echo -e "${RED}✗ 发现 $ISSUES_FOUND 个安全问题，请修复后再提交代码${NC}"
    exit 1
fi
