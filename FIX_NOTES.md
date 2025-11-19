# 前端编译错误修复说明

## 问题描述
前端编译时出现错误：
```
Member not found: 'ApiService.get'
Member not found: 'ApiService.post'
```

## 原因分析
`ApiService` 类中没有通用的 `get` 和 `post` 方法，只有针对特定端点的具体方法。

## 修复方案

### 1. 在 ApiService 中添加通用方法

在 `Frontend/lib/services/api_service.dart` 中添加了两个通用方法：

```dart
/// 通用GET请求
static Future<Map<String, dynamic>> get(String path) async {
  return await _makeRequest(
    () => http.get(Uri.parse('$baseUrl$path'), headers: _buildHeaders()),
    path,
  );
}

/// 通用POST请求
static Future<Map<String, dynamic>> post(String path, Map<String, dynamic>? body) async {
  return await _makeRequest(
    () => http.post(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    ),
    path,
  );
}
```

### 2. ChatService 中的调用

`Frontend/lib/services/chat_service.dart` 中的调用是正确的：

```dart
// 获取会话列表
final resp = await ApiService.get('/api/chat/conversations');

// 发送消息
final resp = await ApiService.post('/api/chat/sendMessage', {
  'contactId': conversationId,
  'messageContent': content,
  'messageType': type == MessageType.text ? 0 : 1,
});
```

## 验证修复

1. 运行测试脚本：
   ```
   test-fix.bat
   ```

2. 重新运行前端：
   ```
   cd Frontend
   flutter run
   ```

## 注意事项

- 这些通用方法使用了现有的 `_makeRequest` 方法，会自动处理认证和Token刷新
- 参数传递格式与现有API一致
- 错误处理机制与现有系统保持一致

## 如果仍有问题

如果编译仍然失败，请检查：

1. Dart文件是否保存
2. 是否有其他语法错误
3. 运行 `flutter clean` 然后重新构建
4. 检查IDE中的错误提示