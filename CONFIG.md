# 配置文件说明

## config.json 配置项

### 基本配置

| 配置项 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `username` | string | 是 | - | 登录用户名 |
| `password` | string | 是 | - | 登录密码 |
| `serverPort` | string | 否 | "20000" | HTTP 服务器监听端口 |
| `logFilePath` | string | 否 | "/tmp/controlpanel_openwrt_arm64.log" | 日志文件路径 |

### 脚本配置

所有脚本路径支持：
- **相对路径**：相对于可执行文件所在目录，例如 `./scripts/naslimit.sh`
- **绝对路径**：完整路径，例如 `/root/scripts/naslimit.sh`

| 配置项 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `nasLimitScript` | string | 否 | NAS 限制脚本路径 |
| `networkLimitScript` | string | 否 | 网络限制脚本路径 |
| `clashLimitScript` | string | 否 | Clash 限制脚本路径 |
| `websiteLimitScripts` | array | 否 | 网站限制脚本数组 |

#### websiteLimitScripts 数组项

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | 是 | 脚本唯一标识符 |
| `scriptPath` | string | 是 | 脚本路径（支持相对/绝对路径） |

## 配置示例

### 示例 1：使用默认端口和日志路径

```json
{
  "username": "admin",
  "password": "mypassword",
  "nasLimitScript": "./scripts/naslimit.sh",
  "networkLimitScript": "./scripts/netlimit.sh",
  "clashLimitScript": "./scripts/clashlimit.sh",
  "websiteLimitScripts": [
    {
      "id": "weblimit_1",
      "scriptPath": "./scripts/weblimit_1.sh"
    }
  ]
}
```

### 示例 2：自定义端口和日志路径

```json
{
  "username": "admin",
  "password": "mypassword",
  "serverPort": "8080",
  "logFilePath": "/var/log/controlpanel.log",
  "nasLimitScript": "./scripts/naslimit.sh",
  "networkLimitScript": "./scripts/netlimit.sh",
  "clashLimitScript": "./scripts/clashlimit.sh",
  "websiteLimitScripts": []
}
```

### 示例 3：使用绝对路径

```json
{
  "username": "admin",
  "password": "mypassword",
  "serverPort": "20000",
  "logFilePath": "/root/logs/controlpanel.log",
  "nasLimitScript": "/root/scripts/naslimit.sh",
  "networkLimitScript": "/root/scripts/netlimit.sh",
  "clashLimitScript": "/root/scripts/clashlimit.sh",
  "websiteLimitScripts": [
    {
      "id": "youtube",
      "scriptPath": "/opt/scripts/youtube_limit.sh"
    },
    {
      "id": "tiktok",
      "scriptPath": "/opt/scripts/tiktok_limit.sh"
    }
  ]
}
```

### 示例 4：混合使用相对和绝对路径

```json
{
  "username": "admin",
  "password": "mypassword",
  "serverPort": "20000",
  "logFilePath": "/tmp/controlpanel.log",
  "nasLimitScript": "./scripts/naslimit.sh",
  "networkLimitScript": "/usr/local/bin/netlimit.sh",
  "clashLimitScript": "./scripts/clashlimit.sh",
  "websiteLimitScripts": [
    {
      "id": "local_script",
      "scriptPath": "./scripts/weblimit_1.sh"
    },
    {
      "id": "system_script",
      "scriptPath": "/etc/controlpanel/weblimit_system.sh"
    }
  ]
}
```

## 路径解析规则

### 相对路径解析顺序

当使用相对路径时（如 `./scripts/naslimit.sh`），程序会按以下顺序查找：

1. **当前工作目录**：`$(pwd)/scripts/naslimit.sh`
2. **可执行文件目录**：`$(dirname $0)/scripts/naslimit.sh`

### 绝对路径

当使用绝对路径时（如 `/root/scripts/naslimit.sh`），程序直接使用该路径。

## 端口配置

### 修改端口

在 `config.json` 中设置 `serverPort`：

```json
{
  "serverPort": "8080"
}
```

### 注意事项

1. 端口范围：1-65535
2. 建议使用 1024 以上的端口（避免需要 root 权限）
3. 确保端口未被其他程序占用
4. 在 OpenWRT 防火墙中开放该端口

### 检查端口占用

```bash
# 检查端口是否被占用
netstat -tuln | grep :20000

# 或使用 ss 命令
ss -tuln | grep :20000
```

## 日志配置

### 修改日志路径

在 `config.json` 中设置 `logFilePath`：

```json
{
  "logFilePath": "/var/log/controlpanel.log"
}
```

### 日志路径建议

#### OpenWRT 环境

1. **临时日志**（重启后丢失）：
   - `/tmp/controlpanel.log`
   - 优点：不占用闪存空间
   - 缺点：重启后丢失

2. **持久化日志**：
   - `/root/logs/controlpanel.log`
   - `/var/log/controlpanel.log`（如果有持久化分区）
   - 优点：重启后保留
   - 缺点：占用闪存空间

#### 一般 Linux 环境

- `/var/log/controlpanel.log`
- `/opt/controlpanel/logs/controlpanel.log`
- `~/logs/controlpanel.log`

### 日志轮转

程序会自动进行日志轮转：
- 当日志文件超过 10MB 时
- 自动重命名为 `.log.old`
- 创建新的日志文件

### 手动清理日志

```bash
# 删除旧日志
rm -f /tmp/controlpanel_openwrt_arm64.log.old

# 清空当前日志
> /tmp/controlpanel_openwrt_arm64.log

# 或者重启服务让程序重新创建
/etc/init.d/controlpanel restart
```

## 环境变量

### APP_CONFIG_PATH

可以通过环境变量指定配置文件路径：

```bash
export APP_CONFIG_PATH=/etc/controlpanel/config.json
./controlpanel_openwrt_arm64
```

或者：

```bash
APP_CONFIG_PATH=/etc/controlpanel/config.json ./controlpanel_openwrt_arm64
```

## 配置验证

### 检查配置文件语法

```bash
# 使用 jq 验证 JSON 格式
cat config.json | jq .

# 或使用 Python
python -m json.tool config.json
```

### 测试配置

```bash
# 启动程序并查看日志
./controlpanel_openwrt_arm64

# 查看日志中的配置信息
grep "Config loaded" /tmp/controlpanel_openwrt_arm64.log
```

## 安全建议

1. **密码强度**：使用强密码，至少 8 位，包含字母、数字、特殊字符
2. **文件权限**：
   ```bash
   chmod 600 config.json  # 只有所有者可读写
   ```
3. **不要提交密码**：
   - 将 `config.json` 添加到 `.gitignore`
   - 使用 `config.example.json` 作为模板

## 故障排查

### 配置文件未找到

```
FATAL: Load config failed: read config /root/config.json: no such file or directory
```

**解决方法**：
1. 确认配置文件存在
2. 检查文件路径
3. 使用 `APP_CONFIG_PATH` 环境变量指定路径

### 端口被占用

```
FATAL: Server listen error: listen tcp :20000: bind: address already in use
```

**解决方法**：
1. 修改 `serverPort` 为其他端口
2. 或停止占用该端口的程序

### 日志文件无法创建

```
FATAL: Failed to initialize logger: failed to open log file: permission denied
```

**解决方法**：
1. 检查日志目录权限
2. 使用有写权限的目录（如 `/tmp`）
3. 或以 root 权限运行

### 脚本未找到

```
ERROR: Script execution failed: script not found: /root/scripts/naslimit.sh
```

**解决方法**：
1. 检查脚本路径是否正确
2. 确认脚本文件存在
3. 检查脚本是否有执行权限：`chmod +x script.sh`
