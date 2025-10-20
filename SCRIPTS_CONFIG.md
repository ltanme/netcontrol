# 脚本配置说明

## 概述

为了保护敏感信息（IP地址、密码、MAC地址、Token等），所有脚本的敏感配置已经分离到独立的配置文件中。

## 配置文件

### scripts/scripts.conf

这是脚本的配置文件，包含所有敏感信息。**此文件不会被提交到版本控制系统。**

### scripts/scripts.conf.example

这是配置文件的模板，可以安全地提交到版本控制系统。

## 初始化配置

### 1. 复制配置模板

```bash
cd scripts
cp scripts.conf.example scripts.conf
```

### 2. 编辑配置文件

```bash
vi scripts.conf
# 或
nano scripts.conf
```

### 3. 填入实际值

根据你的实际环境修改以下配置：

#### NAS 限制配置

```bash
NAS_API_URL="http://你的NAS_IP:端口/toggle"
```

#### 网络限制配置

```bash
# MAC 地址列表，空格分隔
NETWORK_MAC_LIST="AA:BB:CC:DD:EE:FF 11:22:33:44:55:66 ..."
```

#### Clash 配置

```bash
CLASH_API_URL="http://你的Clash_IP:端口/configs"
CLASH_API_TOKEN="你的Token"
CLASH_API_HOST="你的Clash_IP:端口"
```

#### AdGuard Home 配置

```bash
# 主实例
ADGUARD_API_URL="http://你的AdGuard_IP:端口/control/filtering/set_rules"
ADGUARD_USERNAME="你的用户名"
ADGUARD_PASSWORD="你的密码"
ADGUARD_HOST="你的AdGuard_IP:端口"
ADGUARD_SESSION_COOKIE="agh_session=你的会话Cookie"

# 103 实例（如果有多个实例）
ADGUARD_103_API_URL="http://另一个AdGuard_IP:端口/control/filtering/set_rules"
ADGUARD_103_USERNAME="用户名"
ADGUARD_103_PASSWORD="密码"
ADGUARD_103_HOST="另一个AdGuard_IP:端口"
```

## 配置项说明

### NAS 限制脚本 (naslimit.sh)

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `NAS_API_URL` | NAS 控制 API 地址 | `http://192.168.1.100:9991/toggle` |

### 网络限制脚本 (netlimit.sh)

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `NETWORK_MAC_LIST` | 需要控制的设备 MAC 地址列表（空格分隔） | `"AA:BB:CC:DD:EE:FF 11:22:33:44:55:66"` |

### Clash 限制脚本 (clashlimit.sh)

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `CLASH_API_URL` | Clash API 地址 | `http://192.168.1.100:9090/configs` |
| `CLASH_API_TOKEN` | Clash API 认证 Token | `A4Zj6g52` |
| `CLASH_API_HOST` | Clash API Host 头 | `192.168.1.100:9090` |

### 网站限制脚本 (weblimit_1.sh, weblimit_103.sh)

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `ADGUARD_API_URL` | AdGuard Home API 地址 | `http://192.168.1.1:3000/control/filtering/set_rules` |
| `ADGUARD_USERNAME` | AdGuard Home 用户名 | `admin` |
| `ADGUARD_PASSWORD` | AdGuard Home 密码 | `your_password` |
| `ADGUARD_HOST` | AdGuard Home Host 头 | `192.168.1.1:3000` |
| `ADGUARD_SESSION_COOKIE` | AdGuard Home 会话 Cookie | `agh_session=xxx` |

## 部署到 OpenWRT

### 方法 1：手动部署

```bash
# 1. 在本地编辑配置
cd scripts
cp scripts.conf.example scripts.conf
vi scripts.conf  # 填入实际配置

# 2. 上传到 OpenWRT
scp scripts.conf root@openwrt:/root/scripts/

# 3. 验证配置
ssh root@openwrt
cat /root/scripts/scripts.conf
```

### 方法 2：在 OpenWRT 上直接配置

```bash
# 1. SSH 到 OpenWRT
ssh root@openwrt

# 2. 进入脚本目录
cd /root/scripts

# 3. 复制模板
cp scripts.conf.example scripts.conf

# 4. 编辑配置
vi scripts.conf

# 5. 保存并退出
```

## 测试配置

### 测试单个脚本

```bash
# 测试 NAS 限制
./scripts/naslimit.sh enable
./scripts/naslimit.sh disable

# 测试网络限制
./scripts/netlimit.sh enable
./scripts/netlimit.sh disable

# 测试 Clash
./scripts/clashlimit.sh enable
./scripts/clashlimit.sh disable

# 测试网站限制
./scripts/weblimit_1.sh enable
./scripts/weblimit_1.sh disable
```

### 检查配置加载

如果配置文件不存在或配置不完整，脚本会显示错误信息：

```bash
错误: 配置文件不存在: /root/scripts/scripts.conf
请复制 scripts.conf.example 为 scripts.conf 并配置
```

或

```bash
错误: NAS_API_URL 未配置
```

## 安全建议

### 1. 文件权限

```bash
# 限制配置文件权限，只有 root 可读写
chmod 600 scripts/scripts.conf
```

### 2. 不要提交敏感信息

配置文件 `scripts/scripts.conf` 已经添加到 `.gitignore`，不会被提交到版本控制。

### 3. 定期更换密码

定期更换 AdGuard Home、Clash 等服务的密码和 Token。

### 4. 使用强密码

确保所有密码都是强密码，至少包含：
- 8 位以上
- 大小写字母
- 数字
- 特殊字符

## 故障排查

### 配置文件未找到

**错误信息**：
```
错误: 配置文件不存在: /root/scripts/scripts.conf
```

**解决方法**：
```bash
cd /root/scripts
cp scripts.conf.example scripts.conf
vi scripts.conf  # 填入实际配置
```

### 配置项未设置

**错误信息**：
```
错误: NAS_API_URL 未配置
```

**解决方法**：
编辑 `scripts.conf`，确保相关配置项已设置：
```bash
vi scripts/scripts.conf
```

### 脚本执行失败

**检查步骤**：

1. 确认配置文件存在：
```bash
ls -la scripts/scripts.conf
```

2. 检查配置文件内容：
```bash
cat scripts/scripts.conf
```

3. 检查脚本权限：
```bash
chmod +x scripts/*.sh
```

4. 手动测试 API：
```bash
# 测试 NAS API
curl -s "http://你的IP:端口/toggle?vv=1"

# 测试 Clash API
curl -X PATCH "http://你的IP:端口/configs" \
  -H "Authorization: Bearer 你的Token" \
  -H "Content-Type: application/json" \
  -d '{"mode":"Rule"}'
```

## 配置文件格式

配置文件使用 Shell 变量格式：

```bash
# 注释以 # 开头
VARIABLE_NAME="value"

# 多个值用空格分隔（用引号包围）
MAC_LIST="AA:BB:CC:DD:EE:FF 11:22:33:44:55:66"

# URL 格式
API_URL="http://192.168.1.100:9090/api"
```

## 高级配置

### 多实例支持

如果你有多个 AdGuard Home 实例，可以为每个实例配置不同的变量：

```bash
# 主实例
ADGUARD_API_URL="http://192.168.1.1:3000/control/filtering/set_rules"
ADGUARD_USERNAME="admin"
ADGUARD_PASSWORD="password1"

# 103 实例
ADGUARD_103_API_URL="http://192.168.1.103:3000/control/filtering/set_rules"
ADGUARD_103_USERNAME="admin"
ADGUARD_103_PASSWORD="password2"
```

### 环境变量覆盖

配置文件中的值可以被环境变量覆盖：

```bash
# 临时使用不同的 NAS API
NAS_API_URL="http://192.168.2.100:9991/toggle" ./scripts/naslimit.sh enable
```

## 备份和恢复

### 备份配置

```bash
# 备份配置文件
cp scripts/scripts.conf scripts/scripts.conf.backup

# 或者加上日期
cp scripts/scripts.conf scripts/scripts.conf.$(date +%Y%m%d)
```

### 恢复配置

```bash
# 从备份恢复
cp scripts/scripts.conf.backup scripts/scripts.conf
```

## 迁移到新设备

### 1. 导出配置

在旧设备上：
```bash
scp root@old-openwrt:/root/scripts/scripts.conf ./scripts.conf.old
```

### 2. 导入配置

在新设备上：
```bash
scp ./scripts.conf.old root@new-openwrt:/root/scripts/scripts.conf
```

### 3. 验证配置

```bash
ssh root@new-openwrt
cd /root/scripts
./naslimit.sh enable  # 测试
```

## 相关文件

- `scripts/scripts.conf` - 实际配置文件（不提交到 Git）
- `scripts/scripts.conf.example` - 配置模板（提交到 Git）
- `.gitignore` - 包含 `scripts/scripts.conf` 忽略规则
- `scripts/*.sh` - 使用配置的脚本文件

## 更新日志

- 2024-10-20: 初始版本，将敏感信息分离到配置文件
