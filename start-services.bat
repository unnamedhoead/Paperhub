@echo off
chcp 65001 >nul
echo ================================================
echo        PaperHub 服务启动脚本
echo ================================================
echo.

REM 检查Java版本
echo 检查Java版本...
java -version >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到Java，请先安装Java 17和Java 8
    pause
    exit /b 1
)

REM 设置环境变量
set PAPERHUB_BACKEND_DIR=Backend\paperhub
set EASYCHAT_DIR=easychat-java

REM 检查目录是否存在
if not exist "%PAPERHUB_BACKEND_DIR%" (
    echo 错误: PaperHub后端目录不存在: %PAPERHUB_BACKEND_DIR%
    pause
    exit /b 1
)

if not exist "%EASYCHAT_DIR%" (
    echo 错误: EasyChat目录不存在: %EASYCHAT_DIR%
    pause
    exit /b 1
)

echo.
echo 启动服务...
echo.

REM 启动EasyChat服务 (Java 8)
echo 启动EasyChat服务 (端口: 8081)...
start "EasyChat" cmd /k "cd /d %EASYCHAT_DIR% && mvn spring-boot:run -Dspring-boot.run.profiles=paperhub"

REM 等待EasyChat启动
timeout /t 10 /nobreak >nul

REM 启动PaperHub后端服务 (Java 17)
echo 启动PaperHub后端服务 (端口: 8080)...
start "PaperHub Backend" cmd /k "cd /d %PAPERHUB_BACKEND_DIR% && mvn spring-boot:run"

REM 等待PaperHub后端启动
timeout /t 10 /nobreak >nul

echo.
echo ================================================
echo 服务启动完成!
echo - PaperHub后端: http://localhost:8080
echo - EasyChat服务: http://localhost:8081
echo - Flutter前端: 手动运行 flutter run
echo ================================================
echo.
echo 注意: 请确保已安装 Maven 和正确配置 Java 环境变量
echo.
pause