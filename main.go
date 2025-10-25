package main

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	defaultServerPort = "20000"
	sessionTimeout    = 30 * time.Minute
	scriptTimeout     = 30 * time.Second
	defaultLogPath    = "/tmp/controlpanel_openwrt_arm64.log"
	maxLogSize        = 10 * 1024 * 1024 // 10MB
)

type WebsiteLimitScriptConfig struct {
	ID         string `json:"id"`
	ScriptPath string `json:"scriptPath"`
}

type AppConfig struct {
	Username            string                     `json:"username"`
	Password            string                     `json:"password"`
	ServerPort          string                     `json:"serverPort,omitempty"`
	LogFilePath         string                     `json:"logFilePath,omitempty"`
	NasLimitScript      string                     `json:"nasLimitScript"`
	NetworkLimitScript  string                     `json:"networkLimitScript"`
	ClashLimitScript    string                     `json:"clashLimitScript"`
	BanXiaomiScript     string                     `json:"banXiaomiScript"`
	WebsiteLimitScripts []WebsiteLimitScriptConfig `json:"websiteLimitScripts"`
}

var (
	globalConfig   AppConfig
	logger         *log.Logger
	activeSessions = make(map[string]sessionEntry)
	sessionMutex   sync.RWMutex
	serverPort     string
	logFilePath    string
)

// session 存储
type sessionEntry struct {
	lastSeen time.Time
}

// 周期清理过期 session
func startSessionJanitor(ctx context.Context) {
	t := time.NewTicker(1 * time.Minute)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				logger.Printf("ERROR: Session janitor panic recovered: %v\nStack: %s", r, debug.Stack())
			}
			t.Stop()
			logger.Println("INFO: Session janitor stopped")
		}()
		
		logger.Println("INFO: Session janitor started")
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				cleanExpiredSessions()
			}
		}
	}()
}

func cleanExpiredSessions() {
	sessionMutex.Lock()
	defer sessionMutex.Unlock()
	
	now := time.Now()
	cleaned := 0
	for id, s := range activeSessions {
		if now.Sub(s.lastSeen) > sessionTimeout {
			delete(activeSessions, id)
			cleaned++
		}
	}
	if cleaned > 0 {
		logger.Printf("DEBUG: Cleaned %d expired sessions, active sessions: %d", cleaned, len(activeSessions))
	}
}

// 鉴权中间件
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				logger.Printf("ERROR: Auth middleware panic: %v\nStack: %s", r, debug.Stack())
				http.Error(w, "Internal server error", http.StatusInternalServerError)
			}
		}()
		
		c, err := r.Cookie("session")
		if err != nil {
			logger.Printf("DEBUG: No session cookie from %s, redirecting to login", r.RemoteAddr)
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		
		sessionMutex.Lock()
		se, ok := activeSessions[c.Value]
		if !ok || time.Since(se.lastSeen) > sessionTimeout {
			delete(activeSessions, c.Value)
			sessionMutex.Unlock()
			logger.Printf("DEBUG: Invalid or expired session %s from %s", c.Value, r.RemoteAddr)
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		// 滑动刷新
		se.lastSeen = time.Now()
		activeSessions[c.Value] = se
		sessionMutex.Unlock()
		
		next(w, r)
	}
}

// 根据请求判断是否 HTTPS（反代支持）
func isHTTPS(r *http.Request) bool {
	if r.TLS != nil {
		return true
	}
	if strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https") {
		return true
	}
	return false
}

// 处理登录
func handleLogin(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if r := recover(); r != nil {
			logger.Printf("ERROR: Login handler panic: %v\nStack: %s", r, debug.Stack())
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
	}()
	
	if r.Method == "POST" {
		username := r.FormValue("username")
		password := r.FormValue("password")

		uOK := subtle.ConstantTimeCompare([]byte(username), []byte(globalConfig.Username)) == 1
		pOK := subtle.ConstantTimeCompare([]byte(password), []byte(globalConfig.Password)) == 1

		if uOK && pOK {
			// 生成 session id
			sessionMutex.Lock()
			sessionID := fmt.Sprintf("s_%d_%d", time.Now().UnixNano(), len(activeSessions))
			activeSessions[sessionID] = sessionEntry{lastSeen: time.Now()}
			sessionMutex.Unlock()

			logger.Printf("INFO: User logged in successfully from %s, session: %s", r.RemoteAddr, sessionID)

			// 设置会话 cookie（不设置 Expires/MaxAge → 关闭浏览器丢失）
			http.SetCookie(w, &http.Cookie{
				Name:     "session",
				Value:    sessionID,
				Path:     "/",
				HttpOnly: true,
				SameSite: http.SameSiteStrictMode,
				Secure:   isHTTPS(r), // 如果是 https/反代https 才置 true
			})
			// 登录成功后跳到 /?init=1，由前端初始化本次浏览器会话指纹
			http.Redirect(w, r, "/?init=1", http.StatusSeeOther)
			return
		}

		logger.Printf("WARN: Failed login attempt from %s, username: %s", r.RemoteAddr, username)

		// 登录失败页
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, `<!DOCTYPE html><html><head><meta charset="utf-8"><title>登录失败</title>
<style>body{font-family:Arial;text-align:center;margin-top:50px;background:#f5f5f5}.login-container{background:#fff;padding:40px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,.1);max-width:300px;margin:0 auto}.error{color:red;margin:20px 0}input,button{width:100%;padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:5px;box-sizing:border-box}button{background:#007bff;color:#fff;border:none;cursor:pointer;font-size:16px}button:hover{background:#0056b3}</style></head>
<body><div class="login-container"><h2>网络控制面板</h2><div class="error">用户名或密码错误！</div>
<form method="post"><input name="username" placeholder="用户名" required><input type="password" name="password" placeholder="密码" required><button type="submit">登录</button></form></div></body></html>`)
		return
	}

	logger.Printf("DEBUG: Login page requested from %s", r.RemoteAddr)

	// 登录表单
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprint(w, `<!DOCTYPE html><html><head><meta charset="utf-8"><title>网络控制面板 - 登录</title>
<style>body{font-family:Arial;text-align:center;margin-top:50px;background:#f5f5f5}.login-container{background:#fff;padding:40px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,.1);max-width:300px;margin:0 auto}.info{color:#666;font-size:14px;margin-bottom:20px;padding:10px;background:#f8f9fa;border-radius:5px}input,button{width:100%;padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:5px;box-sizing:border-box}button{background:#007bff;color:#fff;border:none;cursor:pointer;font-size:16px}button:hover{background:#0056b3}</style></head>
<body><div class="login-container"><h2>网络控制面板</h2><div class="info">提示：登录状态有效期为30分钟，<b>关闭浏览器后需要重新登录</b></div>
<form method="post"><input name="username" placeholder="用户名" required><input type="password" name="password" placeholder="密码" required><button type="submit">登录</button></form></div></body></html>`)
}

// 登出：支持 GET/POST/XHR/Beacon
func handleLogout(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if r := recover(); r != nil {
			logger.Printf("ERROR: Logout handler panic: %v\nStack: %s", r, debug.Stack())
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
	}()
	
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		fmt.Fprintln(w, "Method not allowed")
		return
	}

	// 删除服务器侧 session
	if c, err := r.Cookie("session"); err == nil {
		sessionMutex.Lock()
		delete(activeSessions, c.Value)
		sessionMutex.Unlock()
		logger.Printf("INFO: User logged out, session: %s, from: %s", c.Value, r.RemoteAddr)
	}

	// 彻底过期 cookie（兼容旧浏览器）
	expired := time.Unix(0, 0)
	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
		Secure:   isHTTPS(r),
		MaxAge:   0,
		Expires:  expired,
	})

	// XHR/JSON 返回，否则重定向
	isAjax := strings.EqualFold(r.Header.Get("X-Requested-With"), "XMLHttpRequest") ||
		strings.Contains(strings.ToLower(r.Header.Get("Accept")), "application/json")

	if isAjax {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		fmt.Fprint(w, `{"ok":true,"redirect":"/login"}`)
		return
	}
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

// 读取配置
func loadConfig(path string) error {
	logger.Printf("DEBUG: Loading config from: %s", path)
	b, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read config %s: %w", path, err)
	}
	if err := json.Unmarshal(b, &globalConfig); err != nil {
		return fmt.Errorf("unmarshal %s: %w", path, err)
	}
	
	// 设置默认值
	if globalConfig.ServerPort == "" {
		globalConfig.ServerPort = defaultServerPort
	}
	serverPort = globalConfig.ServerPort
	
	if globalConfig.LogFilePath == "" {
		globalConfig.LogFilePath = defaultLogPath
	}
	logFilePath = globalConfig.LogFilePath
	
	logger.Printf("INFO: Config loaded successfully from: %s", path)
	logger.Printf("DEBUG: Config - Username: %s, ServerPort: %s, LogPath: %s",
		globalConfig.Username, serverPort, logFilePath)
	logger.Printf("DEBUG: Scripts configured: nas=%v, network=%v, clash=%v, ban_xiaomi=%v, website=%d",
		globalConfig.NasLimitScript != "",
		globalConfig.NetworkLimitScript != "",
		globalConfig.ClashLimitScript != "",
		globalConfig.BanXiaomiScript != "",
		len(globalConfig.WebsiteLimitScripts))
	return nil
}

// 执行脚本
func executeScript(scriptPath, action string) (string, error) {
	startTime := time.Now()
	logger.Printf("DEBUG: Executing script: %s with action: %s", scriptPath, action)
	
	if scriptPath == "" {
		err := fmt.Errorf("script path for action '%s' is empty", action)
		logger.Printf("ERROR: %v", err)
		return "", err
	}
	
	final := scriptPath
	if !filepath.IsAbs(scriptPath) {
		if cwd, err := os.Getwd(); err == nil {
			if _, e := os.Stat(filepath.Join(cwd, scriptPath)); e == nil {
				final = filepath.Join(cwd, scriptPath)
			}
		}
		if final == scriptPath {
			if exe, err := os.Executable(); err == nil {
				final = filepath.Join(filepath.Dir(exe), scriptPath)
			}
		}
	}
	
	if _, err := os.Stat(final); err != nil {
		err := fmt.Errorf("script not found: %s", final)
		logger.Printf("ERROR: %v", err)
		return "", err
	}
	
	logger.Printf("DEBUG: Resolved script path: %s", final)
	
	// 使用 context 实现超时控制
	ctx, cancel := context.WithTimeout(context.Background(), scriptTimeout)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, final, action)
	cmd.Dir = filepath.Dir(final)
	
	out, err := cmd.CombinedOutput()
	duration := time.Since(startTime)
	
	if ctx.Err() == context.DeadlineExceeded {
		err := fmt.Errorf("script execution timeout after %v: %s %s", scriptTimeout, final, action)
		logger.Printf("ERROR: %v", err)
		return string(out), err
	}
	
	if err != nil {
		logger.Printf("ERROR: Script execution failed: %s %s, duration: %v, error: %v, output: %s",
			final, action, duration, err, string(out))
		return string(out), fmt.Errorf("exec '%s %s' failed: %w; out: %s", final, action, err, string(out))
	}
	
	logger.Printf("INFO: Script executed successfully: %s %s, duration: %v", final, action, duration)
	logger.Printf("DEBUG: Script output: %s", string(out))
	return string(out), nil
}

func handleGenericScriptAction(w http.ResponseWriter, r *http.Request, scriptPath, apiName string) {
	defer func() {
		if r := recover(); r != nil {
			logger.Printf("ERROR: Generic script handler panic for %s: %v\nStack: %s", apiName, r, debug.Stack())
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
	}()
	
	action := r.URL.Query().Get("action")
	logger.Printf("INFO: API request: %s, action: %s, from: %s", apiName, action, r.RemoteAddr)
	
	if action != "enable" && action != "disable" {
		logger.Printf("WARN: Invalid action '%s' for %s from %s", action, apiName, r.RemoteAddr)
		http.Error(w, "Invalid action. Use 'enable' or 'disable'.", http.StatusBadRequest)
		return
	}
	
	out, err := executeScript(scriptPath, action)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	if err != nil {
		logger.Printf("ERROR: Script execution failed for %s (%s): %v", apiName, action, err)
		http.Error(w, fmt.Sprintf("Script execution failed for %s (%s):\n%s\n\nError:\n%v", apiName, action, out, err), http.StatusInternalServerError)
		return
	}
	fmt.Fprintln(w, out)
}

func handleWebsiteLimit(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if r := recover(); r != nil {
			logger.Printf("ERROR: Website limit handler panic: %v\nStack: %s", r, debug.Stack())
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
	}()
	
	action := r.URL.Query().Get("action")
	logger.Printf("INFO: API request: website_limit, action: %s, from: %s", action, r.RemoteAddr)
	
	if action != "enable" && action != "disable" {
		logger.Printf("WARN: Invalid action '%s' for website_limit from %s", action, r.RemoteAddr)
		http.Error(w, "Invalid action parameter. Use 'enable' or 'disable'.", http.StatusBadRequest)
		return
	}
	if len(globalConfig.WebsiteLimitScripts) == 0 {
		logger.Printf("ERROR: No website limit scripts configured")
		http.Error(w, "No website limit scripts configured.", http.StatusInternalServerError)
		return
	}
	
	var results []string
	okAll := true
	for _, sc := range globalConfig.WebsiteLimitScripts {
		out, err := executeScript(sc.ScriptPath, action)
		if err != nil {
			okAll = false
			results = append(results, fmt.Sprintf("--- Script ID: %s (Path: %s) ---\n%s\nError: %v", sc.ID, sc.ScriptPath, out, err))
		} else {
			results = append(results, fmt.Sprintf("--- Script ID: %s (Path: %s) ---\n%s", sc.ID, sc.ScriptPath, out))
		}
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	if !okAll {
		w.WriteHeader(http.StatusInternalServerError)
	}
	fmt.Fprintln(w, strings.Join(results, "\n\n"))
}

func handleNasLimit(w http.ResponseWriter, r *http.Request)     { handleGenericScriptAction(w, r, globalConfig.NasLimitScript, "nas_limit") }
func handleNetworkLimit(w http.ResponseWriter, r *http.Request) { handleGenericScriptAction(w, r, globalConfig.NetworkLimitScript, "network_limit") }
func handleClashLimit(w http.ResponseWriter, r *http.Request)   { handleGenericScriptAction(w, r, globalConfig.ClashLimitScript, "clash_limit") }
func handleBanXiaomi(w http.ResponseWriter, r *http.Request)    { handleGenericScriptAction(w, r, globalConfig.BanXiaomiScript, "ban_xiaomi") }

// 初始化日志系统
func initLogger() error {
	// 确保日志目录存在
	logDir := filepath.Dir(logFilePath)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}
	
	// 检查日志文件大小，如果超过限制则轮转
	if info, err := os.Stat(logFilePath); err == nil {
		if info.Size() > maxLogSize {
			backupPath := logFilePath + ".old"
			os.Remove(backupPath) // 删除旧备份
			os.Rename(logFilePath, backupPath)
		}
	}

	logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("failed to open log file: %w", err)
	}

	// 同时输出到文件和标准输出
	multiWriter := io.MultiWriter(os.Stdout, logFile)
	logger = log.New(multiWriter, "", log.LstdFlags|log.Lmicroseconds|log.Lshortfile)
	
	logger.Println("========================================")
	logger.Println("INFO: Logger initialized successfully")
	logger.Printf("INFO: Log file: %s", logFilePath)
	logger.Printf("INFO: PID: %d", os.Getpid())
	
	return nil
}

func main() {
	// 初始化日志（先用标准输出，然后切换到文件）
	logger = log.New(os.Stdout, "", log.LstdFlags)
	
	// 设置默认值
	serverPort = defaultServerPort
	logFilePath = defaultLogPath
	
	// 全局 panic 恢复
	defer func() {
		if r := recover(); r != nil {
			logger.Printf("FATAL: Main panic recovered: %v\nStack: %s", r, debug.Stack())
			os.Exit(1)
		}
	}()

	logger.Println("INFO: Application starting...")

	exePath, err := os.Executable()
	if err != nil {
		logger.Fatalf("FATAL: Get executable path: %v", err)
	}
	baseDir := filepath.Dir(exePath)
	logger.Printf("INFO: Executable path: %s", exePath)
	logger.Printf("INFO: Base directory: %s", baseDir)

	// 配置路径：优先 APP_CONFIG_PATH，其次可执行文件同目录，最后 CWD
	configPath := filepath.Join(baseDir, "config.json")
	if v := os.Getenv("APP_CONFIG_PATH"); v != "" {
		configPath = v
		logger.Printf("INFO: Using config path from APP_CONFIG_PATH: %s", configPath)
	}
	
	if err := loadConfig(configPath); err != nil {
		if cwd, e := os.Getwd(); e == nil {
			logger.Printf("WARN: Failed to load config from %s: %v, trying CWD", configPath, err)
			if err2 := loadConfig(filepath.Join(cwd, "config.json")); err2 != nil {
				logger.Fatalf("FATAL: Load config failed: %v / %v", err, err2)
			}
		} else {
			logger.Fatalf("FATAL: Load config failed: %v; and get CWD failed: %v", err, e)
		}
	}
	
	// 配置加载后重新初始化日志（使用配置文件中的路径）
	if err := initLogger(); err != nil {
		log.Fatalf("FATAL: Failed to initialize logger: %v", err)
	}

	// static 目录：可执行文件同目录优先，否则回退到 CWD/static
	staticBaseDir := filepath.Join(baseDir, "static")
	if _, err := os.Stat(staticBaseDir); os.IsNotExist(err) {
		if cwd, e := os.Getwd(); e == nil {
			staticBaseDir = filepath.Join(cwd, "static")
			logger.Printf("INFO: Static directory not found in base dir, using CWD: %s", staticBaseDir)
		}
	}
	logger.Printf("INFO: Static directory: %s", staticBaseDir)

	// 创建可取消的 context 用于优雅关闭
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 启动 session 清理器
	startSessionJanitor(ctx)

	// 路由
	http.HandleFunc("/login", handleLogin)
	http.HandleFunc("/logout", handleLogout)

	http.HandleFunc("/", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				logger.Printf("ERROR: Static file handler panic: %v\nStack: %s", r, debug.Stack())
				http.Error(w, "Internal server error", http.StatusInternalServerError)
			}
		}()
		
		if r.URL.Path == "/" || r.URL.Path == "/index.html" {
			logger.Printf("DEBUG: Serving index.html to %s", r.RemoteAddr)
			http.ServeFile(w, r, filepath.Join(staticBaseDir, "index.html"))
			return
		}
		reqFile := filepath.Join(staticBaseDir, strings.TrimPrefix(r.URL.Path, "/"))
		if _, err := os.Stat(reqFile); os.IsNotExist(err) {
			logger.Printf("DEBUG: File not found: %s, requested by %s", reqFile, r.RemoteAddr)
			http.NotFound(w, r)
			return
		}
		if ct := mime.TypeByExtension(filepath.Ext(r.URL.Path)); ct != "" {
			w.Header().Set("Content-Type", ct)
		}
		logger.Printf("DEBUG: Serving file: %s to %s", reqFile, r.RemoteAddr)
		http.ServeFile(w, r, reqFile)
	}))

	http.HandleFunc("/api/website_limit", authMiddleware(handleWebsiteLimit))
	http.HandleFunc("/api/nas_limit", authMiddleware(handleNasLimit))
	http.HandleFunc("/api/network_limit", authMiddleware(handleNetworkLimit))
	http.HandleFunc("/api/clash_limit", authMiddleware(handleClashLimit))
	http.HandleFunc("/api/ban_xiaomi", authMiddleware(handleBanXiaomi))

	// 创建 HTTP 服务器
	server := &http.Server{
		Addr:         ":" + serverPort,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 监听系统信号以实现优雅关闭
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM, syscall.SIGQUIT)

	// 在 goroutine 中启动服务器
	go func() {
		logger.Printf("INFO: Starting server on http://0.0.0.0:%s", serverPort)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatalf("FATAL: Server listen error: %v", err)
		}
	}()

	// 等待中断信号
	sig := <-sigChan
	logger.Printf("INFO: Received signal: %v, shutting down gracefully...", sig)

	// 优雅关闭服务器
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Printf("ERROR: Server shutdown error: %v", err)
	}

	// 取消 session janitor
	cancel()

	logger.Println("INFO: Server stopped gracefully")
}
