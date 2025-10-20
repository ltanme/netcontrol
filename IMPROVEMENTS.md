# 控制面板程序改进说明

## 改进内容

### 1. 完善的日志系统
- **日志文件**: 可配置，默认 `/tmp/controlpanel_openwrt_arm64.log`
- **日志级别**: DEBUG, INFO, WARN, ERROR, FATAL
- **日志轮转**: 当日志文件超过 10MB 时自动轮转
- **双输出**: 同时输出到文件和标准输出
- **详细信息**: 包含时间戳、文件名、行号
- **自动创建目录**: 日志目录不存在时自动创建

### 2. 错误处理和恢复机制
- **全局 Panic 恢复**: 所有 HTTP 处理器都有 panic 恢复机制
- **Goroutine 保护**: Session 清理器有 panic 恢复
- **详细堆栈**: Panic 时输出完整堆栈信息

### 3. 并发安全
- **互斥锁保护**: activeSessions map 使用 sync.RWMutex 保护
- **线程安全**: 所有并发访问都已加锁

### 4. 超时控制
- **脚本执行超时**: 30 秒超时限制，防止脚本挂起
- **HTTP 超时**: 
  - ReadTimeout: 15 秒
  - WriteTimeout: 15 秒
  - IdleTimeout: 60 秒

### 5. 优雅关闭
- **信号处理**: 捕获 SIGINT, SIGTERM, SIGQUIT
- **优雅关闭**: 30 秒超时的优雅关闭
- **资源清理**: 正确清理 session janitor 和 HTTP 服务器

### 6. 详细的调试信息
- 启动时记录所有配置信息
- 记录每个 HTTP 请求
- 记录脚本执行详情和耗时
- 记录登录/登出事件
- 记录 session 清理信息

### 7. 灵活的配置系统
- **端口配置**: 可自定义服务器端口，默认 20000
- **日志路径配置**: 可自定义日志文件路径
- **脚本路径**: 支持相对路径和绝对路径
- **配置验证**: 启动时验证并记录所有配置

## 编译和部署

### 在 macOS 上编译 OpenWRT ARM64 版本

```bash
# 使用现有的编译脚本
./build_openwrt_arm64.bat

# 或手动编译
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o controlpanel_openwrt_arm64 main.go
```

### 部署到 OpenWRT

1. 上传文件到 OpenWRT:
```bash
scp controlpanel_openwrt_arm64 config.json root@openwrt:/root/
scp -r scripts static root@openwrt:/root/
scp start_controlpanel_improved.sh install_service.sh root@openwrt:/root/
```

2. 在 OpenWRT 上安装服务:
```bash
ssh root@openwrt
cd /root
chmod +x install_service.sh
./install_service.sh
```

3. 启动服务:
```bash
/etc/init.d/controlpanel start
```

## 使用方法

### 服务管理

```bash
# 启动服务
/etc/init.d/controlpanel start

# 停止服务
/etc/init.d/controlpanel stop

# 重启服务
/etc/init.d/controlpanel restart

# 查看状态
/etc/init.d/controlpanel status
```

### 查看日志

```bash
# 查看应用日志
tail -f /tmp/controlpanel_openwrt_arm64.log

# 查看启动日志
tail -f /tmp/controlpanel_startup.log

# 查看最近的错误
grep ERROR /tmp/controlpanel_openwrt_arm64.log

# 查看最近的警告
grep WARN /tmp/controlpanel_openwrt_arm64.log
```

### 手动管理

如果不想使用服务，可以直接使用改进的启动脚本:

```bash
# 启动
./start_controlpanel_improved.sh start

# 停止
./start_controlpanel_improved.sh stop

# 重启
./start_controlpanel_improved.sh restart

# 查看状态
./start_controlpanel_improved.sh status

# 健康检查
./start_controlpanel_improved.sh health

# 监控模式（自动重启）
./start_controlpanel_improved.sh monitor
```

## 故障排查

### 程序无法启动

1. 检查日志文件:
```bash
cat /tmp/controlpanel_openwrt_arm64.log
```

2. 检查配置文件:
```bash
cat /root/config.json
```

3. 检查文件权限:
```bash
ls -la /root/controlpanel_openwrt_arm64
chmod +x /root/controlpanel_openwrt_arm64
```

### 程序频繁崩溃

1. 查看崩溃日志:
```bash
grep -A 20 "FATAL\|panic" /tmp/controlpanel_openwrt_arm64.log
```

2. 检查系统资源:
```bash
free -m
df -h
top
```

3. 检查脚本执行:
```bash
# 手动测试脚本
/root/scripts/naslimit.sh enable
/root/scripts/naslimit.sh disable
```

### 脚本执行超时

如果脚本执行时间超过 30 秒，可以修改 `main.go` 中的 `scriptTimeout` 常量:

```go
const (
    scriptTimeout = 60 * time.Second  // 改为 60 秒
)
```

然后重新编译。

### 端口被占用

检查端口 20000 是否被占用:
```bash
netstat -tuln | grep 20000
```

如需修改端口，编辑 `main.go` 中的 `serverPort` 常量。

## 日志级别说明

- **DEBUG**: 详细的调试信息（文件访问、session 操作等）
- **INFO**: 一般信息（启动、配置加载、用户登录等）
- **WARN**: 警告信息（登录失败、配置问题等）
- **ERROR**: 错误信息（脚本执行失败、文件不存在等）
- **FATAL**: 致命错误（程序无法继续运行）

## 性能优化建议

1. **日志文件**: 定期清理旧日志文件
```bash
# 添加到 crontab
0 0 * * * rm -f /tmp/controlpanel_openwrt_arm64.log.old
```

2. **Session 清理**: 默认每分钟清理一次过期 session，可根据需要调整

3. **内存使用**: 程序使用最小化内存，适合 OpenWRT 环境

## 监控和告警

可以配合 OpenWRT 的监控工具使用:

```bash
# 添加到 crontab 进行健康检查
*/5 * * * * /root/start_controlpanel_improved.sh health || /root/start_controlpanel_improved.sh restart
```

## 技术细节

### 改进的关键点

1. **Context 管理**: 使用 context 实现优雅关闭和超时控制
2. **Mutex 保护**: 所有共享数据结构都有适当的锁保护
3. **Panic 恢复**: 每个可能 panic 的地方都有 defer recover
4. **资源清理**: 确保所有资源（ticker、goroutine）都能正确清理
5. **详细日志**: 记录所有关键操作和错误信息

### 已知限制

1. 日志文件在 `/tmp` 目录，重启后会丢失（OpenWRT 特性）
2. 如需持久化日志，可修改 `logFilePath` 到 `/root` 或其他持久化目录
3. 脚本执行超时设置为 30 秒，长时间运行的脚本需要调整

## 更新历史

- 2024-10-20: 初始改进版本
  - 添加完整日志系统
  - 添加 panic 恢复机制
  - 添加并发安全保护
  - 添加超时控制
  - 添加优雅关闭
  - 创建改进的启动脚本
