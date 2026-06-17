import '../core/http_client.dart';

class HistoryApi {
  /// 获取当前登录用户的浏览历史（最新在前）
  /// GET /browse-history?limit=50
  static Future<Map<String, dynamic>> getBrowseHistory({int limit = 50}) async {
    return HttpClient.instance.get('/browse-history', queryParameters: {
      'limit': limit.toString(),
    });
  }

  /// 记录一条浏览历史
  /// POST /browse-history  body: { postId, title }
  static Future<Map<String, dynamic>> addBrowseHistory({
    required String postId,
    required String title,
  }) async {
    return HttpClient.instance.post('/browse-history', body: {
      'postId': postId,
      'title': title,
    });
  }

  /// 删除一条浏览历史
  /// DELETE /browse-history/{postId}
  static Future<Map<String, dynamic>> deleteBrowseHistory(String postId) async {
    return HttpClient.instance.delete('/browse-history/$postId');
  }

  /// 清空当前用户的浏览历史
  /// DELETE /browse-history
  static Future<Map<String, dynamic>> clearBrowseHistory() async {
    return HttpClient.instance.delete('/browse-history');
  }

  /// 获取当前登录用户的搜索历史（最新在前）
  /// GET /search-history?limit=20
  static Future<Map<String, dynamic>> getSearchHistory({int limit = 20}) async {
    return HttpClient.instance.get('/search-history', queryParameters: {
      'limit': limit.toString(),
    });
  }

  /// 记录一条搜索历史
  /// POST /search-history  body: { keyword, searchType }
  static Future<Map<String, dynamic>> addSearchHistory({
    required String keyword,
    required String searchType,
  }) async {
    return HttpClient.instance.post('/search-history', body: {
      'keyword': keyword,
      'searchType': searchType,
    });
  }

  /// 删除一条搜索历史
  /// DELETE /search-history/{id}
  static Future<Map<String, dynamic>> deleteSearchHistory(String id) async {
    return HttpClient.instance.delete('/search-history/$id');
  }

  /// 清空当前用户的搜索历史
  /// DELETE /search-history
  static Future<Map<String, dynamic>> clearSearchHistory() async {
    return HttpClient.instance.delete('/search-history');
  }

  /// 获取用户最近搜索的关键词（用于推荐算法）
  /// GET /search-history/recent-keywords?limit=50
  static Future<Map<String, dynamic>> getRecentSearchKeywords({
    int limit = 50,
  }) async {
    return HttpClient.instance.get('/search-history/recent-keywords',
        queryParameters: {'limit': limit.toString()});
  }

  /// 获取热搜榜单
  /// GET /hot-searches?limit=20&type=keyword|tag|author
  static Future<Map<String, dynamic>> getHotSearches({
    int limit = 20,
    String? type,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (type != null && type.isNotEmpty) {
      params['type'] = type;
    }
    return HttpClient.instance.get('/hot-searches', queryParameters: params);
  }
}
