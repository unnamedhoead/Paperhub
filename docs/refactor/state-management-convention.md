# Paperhub 前端状态管理统一规范

> 生效日期: Wave2 收尾 | 适用范围: 所有 Flutter `lib/` 新增与修改代码 | 审查发现: R3 (状态管理未统一)

## 选定方案：ChangeNotifier（Flutter 内置，零依赖）

不引入 Provider/Riverpod/Bloc，使用 Flutter SDK 自带的 `ChangeNotifier` + `addListener` 模式。

**选择理由**：
- Flutter SDK 内置，零额外依赖
- AdminController 和 FollowController 已使用此模式
- 足够轻量，不强制全局 Provider tree
- 后续可无缝升级到 Provider（Provider 本身就是 ChangeNotifier 的 DI 容器）

## 两种 Controller 类型

### 类型 A：有状态 Controller → `extends ChangeNotifier`

适用于：持有可变状态、需要通知 UI 刷新的控制器。

```dart
class MyController extends ChangeNotifier {
  List<Item> _items = [];
  bool _loading = false;

  List<Item> get items => _items;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _items = await api.fetch();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // 清理资源
    super.dispose();
  }
}
```

**Screen 使用方式**：
```dart
class _MyScreenState extends State<MyScreen> {
  late final MyController _controller = MyController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 类型 B：无状态数据加载器 → 普通 Dart 类（实例方法，非 static）

适用于：不持有可变状态、仅封装 API 调用和数据转换的逻辑。

```dart
class ProfileDataLoader {
  final UserApi _userApi;
  ProfileDataLoader(this._userApi);

  Future<UserProfile> loadProfile(String userId) async { ... }
  Future<List<Post>> loadPosts(String userId, {int page = 1}) async { ... }
}
```

**禁止**：纯 static 方法类（不可测试、不可替换依赖）。

## 现有 Controller 对齐状态

| Controller | 当前 | Wave2 收尾 | Wave3 |
|---|---|---|---|
| `AdminController` | `extends ChangeNotifier` ✅ | — | — |
| `FollowController` | `extends ChangeNotifier` ✅ | — | — |
| `ProfileController` | 纯 static 方法 | **标记为 tech debt**，重命名为 `ProfileService` | 改为实例类 |
| `note_editor_controller.dart` | `part of` + `extension on _State` ❌ | **标记为 tech debt** | 改为独立 `ChangeNotifier` 类 |
| 其余 16+ screen | 裸 `setState()` | **不阻塞**。后续新增状态逻辑时迁移到 Controller | 逐步迁移 |

## 禁止事项

| 禁止 | 原因 |
|---|---|
| `part of` + `extension on _State` 作为 "controller" | 无法独立测试、无法被其他文件 import |
| 纯 static 方法类作为 controller | 不可测试、不可替换、不可 mock |
| 混用 `.then().catchError()` 和 `try/catch/await` | 统一用 `try/catch` + `await` |
| 裸 `.then()` 无错误处理 | 异步调用必须有错误处理 |

## 相关文件

- `docs/refactor/wave1-agent-constraints.md` — G7/G8/G9 前端约束
- `docs/refactor/wave2-frontend-plan.md` — Wave2 前端分工
