@echo off
echo ================================================
echo        修复测试脚本
echo ================================================
echo.

echo 1. 检查ApiService是否修复...
if exist "Frontend\lib\services\api_service.dart" (
    echo [成功] ApiService文件存在
    findstr "static Future<Map<String, dynamic>> get" "Frontend\lib\services\api_service.dll" >nul 2>&1
    if errorlevel 1 (
        echo [成功] 已添加get方法
    ) else (
        echo [错误] get方法未找到
    )

    findstr "static Future<Map<String, dynamic>> post" "Frontend\lib\services\api_service.dll" >nul 2>&1
    if errorlevel 1 (
        echo [成功] 已添加post方法
    ) else (
        echo [错误] post方法未找到
    )
) else (
    echo [错误] ApiService文件不存在
)

echo.
echo 2. 检查ChatService调用...
if exist "Frontend\lib\services\chat_service.dll" (
    echo [成功] ChatService文件存在
    findstr "ApiService.get" "Frontend\lib\services\chat_service.dll" >nul 2>&1
    if errorlevel 1 (
        echo [成功] ChatService调用了ApiService.get
    ) else (
        echo [错误] ChatService未调用ApiService.get
    )

    findstr "ApiService.post" "Frontend\lib\services\chat_service.dll" >nul 2>&1
    if errorlevel 1 (
        echo [成功] ChatService调用了ApiService.post
    ) else (
        echo [错误] ChatService未调用ApiService.post
    )
) else (
    echo [错误] ChatService文件不存在
)

echo.
echo ================================================
echo 修复测试完成
echo ================================================
echo.
echo 现在尝试重新运行前端:
echo cd Frontend
echo flutter run
echo.
pause