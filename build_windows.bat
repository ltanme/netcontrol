@echo off
REM Batch script to build the Go application for Windows (local development/testing)

echo Building for Windows (local development/testing)...

REM Set Go environment variables for Windows compilation
REM GOOS=windows is usually the default when running on Windows, but explicitly setting is good practice.
SET GOOS=windows
REM GOARCH can be amd64 (for 64-bit) or 386 (for 32-bit).
REM Modern systems are typically amd64.
SET GOARCH=amd64

REM CGO_ENABLED can be 0 for a pure Go binary, or 1 if you use Cgo.
REM For local Windows builds, it might not matter as much as for cross-compilation.
REM Setting to 0 can sometimes help avoid issues if a C compiler isn't readily available or configured.
SET CGO_ENABLED=0

REM Define the output binary name.
SET OUTPUT_NAME=controlpanel_windows.exe

REM Check if main.go exists in the current directory.
IF NOT EXIST main.go (
    echo ERROR: main.go not found in the current directory.
    echo Please run this script from the root of your Go project.
    GOTO :EOF
)

echo Cleaning up previous build (if any)...
del %OUTPUT_NAME% 2>NUL

REM The core build command.
REM -o specifies the output file name.
REM -ldflags="-s -w" are linker flags to strip debug symbols and DWARF information, reducing binary size.
REM For local debugging, you might want to omit -ldflags="-s -w" to keep debug symbols.
REM For a "release" style local build, keeping them is fine.

echo Running Go build command: go build -o %OUTPUT_NAME% -ldflags="-s -w" main.go
REM If you want a build with full debug symbols for local debugging, use:
REM echo Running Go build command: go build -o %OUTPUT_NAME% main.go
go build -o %OUTPUT_NAME% -ldflags="-s -w" main.go

REM Check if the build command was successful.
IF ERRORLEVEL 1 (
    echo.
    echo =======================================
    echo      ERROR: Go build failed.
    echo =======================================
    GOTO :EOF
)

REM Success message.
echo.
echo ==================================================================================
echo Build successful! Output executable: %OUTPUT_NAME%
echo ==================================================================================
echo.
echo To run the application:
echo 1. Ensure 'config.json' is in the same directory as %OUTPUT_NAME%.
echo 2. Ensure the 'static' directory (with index.html, css, js) is in the same directory.
echo 3. Ensure the 'scripts' directory is in the same directory.
echo    (Note: .sh scripts in the 'scripts' directory will likely NOT run correctly on Windows
echo     without a compatible shell environment like WSL or Git Bash, and code adjustments
echo     to use that shell. This build is primarily for the Go application itself.)
echo 4. Open a command prompt or PowerShell, navigate to this directory, and run:
echo    .\%OUTPUT_NAME%
echo.

REM Optional: Clean up environment variables.
SET GOOS=
SET GOARCH=
SET CGO_ENABLED=
SET OUTPUT_NAME=

echo Script finished.

:EOF