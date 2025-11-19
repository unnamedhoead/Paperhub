@echo off
echo ================================================
echo        PaperHub 服务启动脚本
echo ================================================
echo.

echo 启动EasyChat服务 (端口: 8081)...
start "EasyChat" cmd /k "cd /d easychat-java && mvn spring-boot:run -Dspring-boot.run.profiles=paperhub"

timeout /t 10 /nobreak >nul

echo 启动PaperHub后端服务 (端口: 8080)...
start "PaperHub Backend" cmd /k "cd /d Backend\paperhub && mvn spring-boot:run"

echo.
echo ================================================
echo 服务启动中...
echo - PaperHub后端: http://localhost:8080
echo - EasyChat服务: http://localhost:8081
echo ================================================
echo.
echo 注意: 请确保已安装 Maven 和正确配置 Java 环境变量
echo 如果服务启动失败，请手动检查 Java 和 Maven 配置
echo.
pause