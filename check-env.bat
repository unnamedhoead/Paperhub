@echo off
echo ================================================
echo        环境检查脚本
echo ================================================
echo.

echo 1. 检查Java版本...
java -version 2>&1 | find "version"
if errorlevel 1 (
    echo [错误] 未找到Java
) else (
    echo [成功] Java已安装
)

echo.
echo 2. 检查Maven...
mvn -version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到Maven
) else (
    echo [成功] Maven已安装
)

echo.
echo 3. 检查项目目录...
if exist "Backend\paperhub" (
    echo [成功] PaperHub后端目录存在
) else (
    echo [错误] PaperHub后端目录不存在
)

if exist "easychat-java" (
    echo [成功] EasyChat目录存在
) else (
    echo [错误] EasyChat目录不存在
)

if exist "Frontend" (
    echo [成功] Frontend目录存在
) else (
    echo [错误] Frontend目录不存在
)

echo.
echo ================================================
echo 环境检查完成
echo ================================================
echo.
pause