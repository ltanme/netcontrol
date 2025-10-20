@echo off
REM Batch script to build the Go application for OpenWrt ARM64

echo Building for OpenWrt ARM64...

REM Set Go environment variables for cross-compilation
REM These are critical for targeting the correct platform.
SET GOOS=linux
SET GOARCH=arm64

REM Disable CGO for a statically linked binary, often preferred for cross-compilation.
REM If your Go code (or dependencies) explicitly requires CGO, you might need a more complex setup with a C cross-compiler.
SET CGO_ENABLED=0

REM Define the output binary name for clarity.
SET OUTPUT_NAME=controlpanel_openwrt_arm64

REM Check if main.go exists in the current directory.
REM The script assumes it's run from the project root.
IF NOT EXIST main.go (
    echo ERROR: main.go not found in the current directory.
    echo Please run this script from the root of your Go project.
    GOTO :EOF
)

echo Cleaning up previous build (if any)...
del %OUTPUT_NAME% 2>NUL

REM The core build command.
REM -o specifies the output file name.
REM -ldflags="-s -w" are linker flags to strip debug symbols (-s) and DWARF information (-w),
REM which significantly reduces the binary size.

echo Running Go build command: go build -o %OUTPUT_NAME% -ldflags="-s -w" main.go
go build -o %OUTPUT_NAME% -ldflags="-s -w" main.go

REM Check if the build command was successful.
IF ERRORLEVEL 1 (
    echo.
    echo =======================================
    echo      ERROR: Go build failed.
    echo =======================================
    GOTO :EOF
)

REM Success message and instructions.
echo.
echo ==================================================================================
CHOICE /C YN /N /M "Build successful! Output: %OUTPUT_NAME%. View deployment checklist? (Y/N)"
IF ERRORLEVEL 2 GOTO EndPrompt
IF ERRORLEVEL 1 GOTO ShowChecklist

:ShowChecklist
echo.
echo Deployment Checklist for OpenWrt ARM64:
ECHO 1. Transfer the executable '%OUTPUT_NAME%' to your OpenWrt device.
ECHO    (e.g., to /opt/controlpanel/%OUTPUT_NAME%)
ECHO 2. Transfer the 'config.json' file to the same directory as the executable.
ECHO    (e.g., /opt/controlpanel/config.json)
ECHO 3. Transfer the entire 'static' directory and its contents (index.html, CSS, JS files).
ECHO    (e.g., /opt/controlpanel/static/)
ECHO 4. Transfer the entire 'scripts' directory and its contents (.sh files).
ECHO    (e.g., /opt/controlpanel/scripts/)
ECHO 5. On the OpenWrt device, make the executable runnable:
ECHO    chmod +x /path/to/your/%OUTPUT_NAME%
ECHO 6. Make all your shell scripts executable:
ECHO    chmod +x /path/to/your/scripts/*.sh
ECHO 7. Navigate to the directory and run the application:
ECHO    cd /path/to/your/
ECHO    ./%OUTPUT_NAME%
ECHO 8. Ensure port 20000 (or your configured port) is open in the OpenWrt firewall.
echo ==================================================================================
echo.

:EndPrompt

REM Optional: Clean up environment variables set by this script for the current session.
REM This is good practice but not strictly necessary for the script to function.
SET GOOS=
SET GOARCH=
SET CGO_ENABLED=
SET OUTPUT_NAME=

echo Script finished.

:EOF
