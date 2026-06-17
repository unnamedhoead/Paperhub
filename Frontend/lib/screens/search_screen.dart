// PaperHub 搜索页。
//
// 骨架职责：协调状态（搜索类型 / 历史 / 热搜）+ 组合各 search/ 子 Widget。
// - 搜索入口、搜索方式选择、历史区、热搜区分别由
//   SearchBarHeader / SearchTypeSelector / SearchHistorySection / HotSearchSection 渲染。
// - 历史通过 SearchHistoryService 持久化；热搜通过 ApiService.getHotSearches 拉取。
// - 提交搜索 / 点击历史 / 点击热搜统一走 _recordAndNavigate（写历史 + 跳转结果页）。
import 'package:flutter/material.dart';
import '../models/search_model.dart';
import '../services/search_history_service.dart';
import '../services/api_service.dart';
import 'search/hot_search_section.dart';
import 'search/search_bar.dart';
import 'search/search_history_section.dart';
import 'search/search_type_selector.dart';
import 'search_results_screen.dart';

/// 搜索页面（Stateful）
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// 搜索输入框控制器
  final TextEditingController _searchController = TextEditingController();
  /// 控制焦点，用于历史/热搜回填后聚焦输入框
  final FocusNode _searchFocusNode = FocusNode();

  /// 当前选中的搜索方式：'keyword' | 'tag' | 'author'
  String _selectedSearchType = 'keyword';
  /// 搜索方式选择器展开状态（用于控制箭头图标）
  bool _isSearchTypeExpanded = false;
  /// 搜索历史列表（按时间倒序，最新在前，由服务层返回）
  List<SearchHistoryItem> _searchHistory = [];
  /// 历史加载中的占位状态
  bool _isLoading = true;
  /// 历史记录展开状态（false：折叠显示最近5条；true：展开显示全部）
  bool _isHistoryExpanded = false;
  /// 热搜榜单列表
  List<HotSearchItem> _hotSearches = [];
  /// 热搜加载中的占位状态
  bool _isLoadingHotSearches = true;
  /// 热搜加载错误信息
  String? _hotSearchesError;

  // 搜索方式选项
  /// key 为内部值，value 为展示文案；用于渲染选择器与提示语映射。
  /// 合法 key：'keyword' | 'tag' | 'author'。
  final Map<String, String> _searchTypeOptions = {
    'keyword': '关键词',
    'tag': '标签',
    'author': '作者',
  };

  // 搜索提示文本
  /// 与 `_searchTypeOptions` 的 key 对应的占位提示文案。
  /// 若新增搜索方式，请同步补充此映射。
  final Map<String, String> _searchHints = {
    'keyword': '搜索笔记、论文标题',
    'tag': '搜索领域标签',
    'author': '搜索作者名称',
  };

  @override
  void initState() {
    super.initState();
    // 进入页面后加载本地搜索历史。
    _loadSearchHistory();
    // 加载热搜榜单
    _loadHotSearches();
  }

  /// 加载本地搜索历史（带 `_isLoading` 占位，完成后渲染列表）。
  Future<void> _loadSearchHistory() async {
    setState(() {
      _isLoading = true;
    });

    final history = await SearchHistoryService.getSearchHistory();

    setState(() {
      _searchHistory = history;
      _isLoading = false;
    });
  }

  /// 加载热搜榜单（带 `_isLoadingHotSearches` 占位；失败写 `_hotSearchesError`）。
  Future<void> _loadHotSearches() async {
    setState(() {
      _isLoadingHotSearches = true;
      _hotSearchesError = null; // 清除之前的错误
    });

    try {
      final response = await ApiService.getHotSearches(limit: 20);
      if (response['statusCode'] == 200) {
        final data = response['body'];
        final List<dynamic> items = data['items'] ?? [];

        // 转换为 HotSearchItem 列表
        List<HotSearchItem> hotSearches = items.map((item) {
          return HotSearchItem(
            rank: item['rank'] as int,
            title: item['keyword'] as String,
            tag: item['tag'] as String?,
            heat: (item['heat'] as num).toDouble(),
            searchType: item['searchType'] as String,
          );
        }).toList();

        setState(() {
          _hotSearches = hotSearches;
          _isLoadingHotSearches = false;
        });
      } else {
        // API请求失败，显示错误信息
        final errorMessage = response['body']?['message'] ?? '加载热搜失败';
        setState(() {
          _hotSearches = [];
          _isLoadingHotSearches = false;
          _hotSearchesError = errorMessage;
        });
      }
    } catch (e) {
      // 网络错误或其他异常
      setState(() {
        _hotSearches = [];
        _isLoadingHotSearches = false;
        _hotSearchesError = '网络连接失败，请检查网络后重试';
      });
    }
  }

  /// 修改搜索方式（单选）
  /// - 收起展开面板
  /// - 同步 `_selectedSearchType`，影响搜索框提示文案
  void _onSearchTypeChanged(String type) {
    setState(() {
      _selectedSearchType = type;
      _isSearchTypeExpanded = false;
    });
  }

  /// 写入一次搜索历史并跳转到结果页（提交/点击历史/点击热搜共用）。
  /// keyword 已去空白且非空；服务层负责去重与计数更新。
  void _recordAndNavigate(String keyword, String searchType) {
    SearchHistoryService.addSearchHistory(
      SearchHistoryItem(
        id: SearchHistoryService.generateId(),
        keyword: keyword,
        searchType: searchType,
        timestamp: DateTime.now(),
      ),
    ).then((_) => _loadSearchHistory()); // 重新加载历史记录

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          query: keyword,
          searchType: searchType,
        ),
      ),
    );
  }

  /// 提交搜索：去空白后非空则写历史并跳转，使用当前搜索类型。
  void _onSearchSubmitted(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    _recordAndNavigate(keyword, _selectedSearchType);
  }

  /// 点击历史记录项：回填关键词与其搜索类型、聚焦输入框，再写历史并跳转。
  void _onHistoryItemTap(SearchHistoryItem item) {
    final keyword = item.keyword.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _searchController.text = keyword;
      _selectedSearchType = item.searchType;
    });
    _searchFocusNode.requestFocus();

    _recordAndNavigate(keyword, item.searchType);
  }

  /// 点击热搜项：回填标题（保持当前搜索类型）、聚焦输入框，再写历史并跳转。
  void _onHotSearchTap(HotSearchItem item) {
    final keyword = item.title.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _searchController.text = keyword; // 不改变 _selectedSearchType
    });
    _searchFocusNode.requestFocus();

    _recordAndNavigate(keyword, _selectedSearchType);
  }

  /// 清空全部历史记录
  void _onClearHistory() async {
    await SearchHistoryService.clearSearchHistory();
    _loadSearchHistory();
  }

  /// 删除单条历史记录
  void _onDeleteHistoryItem(String id) async {
    await SearchHistoryService.removeSearchHistory(id);
    _loadSearchHistory();
  }

  @override
  /// 页面骨架：
  /// - 顶部搜索栏（返回、输入框、搜索按钮）
  /// - 内容区为 `CustomScrollView`，依次包含：
  ///   1) 搜索方式选择器（ExpansionTile）
  ///   2) 历史记录区（加载中/空/列表）
  ///   3) 热搜榜区（列表）
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            SearchBarHeader(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: _searchHints[_selectedSearchType],
              onSubmitted: _onSearchSubmitted,
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
              onBack: () => Navigator.pop(context),
            ),

            // 内容区域
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // 搜索方式选择器
                  SearchTypeSelector(
                    options: _searchTypeOptions,
                    selectedType: _selectedSearchType,
                    isExpanded: _isSearchTypeExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isSearchTypeExpanded = expanded;
                      });
                    },
                    onTypeChanged: _onSearchTypeChanged,
                  ),

                  // 历史记录区域
                  SearchHistorySection(
                    history: _searchHistory,
                    isLoading: _isLoading,
                    isExpanded: _isHistoryExpanded,
                    searchTypeLabels: _searchTypeOptions,
                    onClearHistory: _onClearHistory,
                    onToggleExpand: () {
                      setState(() {
                        _isHistoryExpanded = !_isHistoryExpanded;
                      });
                    },
                    onItemTap: _onHistoryItemTap,
                    onDeleteItem: _onDeleteHistoryItem,
                  ),

                  // 热搜榜区域
                  HotSearchSection(
                    hotSearches: _hotSearches,
                    isLoading: _isLoadingHotSearches,
                    error: _hotSearchesError,
                    onRefresh: _loadHotSearches,
                    onItemTap: _onHotSearchTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  /// 释放输入与焦点资源，避免内存泄漏
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
