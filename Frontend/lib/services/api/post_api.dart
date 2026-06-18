import '../core/http_client.dart';

class PostApi {
  /// 获取帖子列表
  /// @param page 页码，从1开始
  /// @param pageSize 每页数量，默认20
  /// @param disciplineTag 可选：按分区/标签过滤帖子
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int pageSize = 20,
    String? disciplineTag,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (disciplineTag != null && disciplineTag.isNotEmpty)
        'tag': disciplineTag,
    };
    return HttpClient.instance.get('/posts', queryParameters: queryParameters);
  }

  /// 获取首页推荐帖子列表
  /// - 登录用户：后端根据研究方向、浏览历史、收藏、发帖兴趣、时间和热度综合排序
  /// - 未登录用户：后端会退化为普通按时间排序（等价于 /posts）
  static Future<Map<String, dynamic>> getRecommendedPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/posts/recommendations',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取"关注"信息流
  /// 只返回当前登录用户关注的作者发布的帖子
  /// GET /posts/following?page=1&pageSize=20
  static Future<Map<String, dynamic>> getFollowingPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/posts/following', queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
  }

  /// 获取帖子详情
  /// @param postId 帖子ID
  static Future<Map<String, dynamic>> getPost(String postId) async {
    return HttpClient.instance.get('/posts/$postId');
  }

  /// 获取帖子详情（支持不同状态的帖子）
  /// 兼容旧用法：获取帖子详情（支持字符串或int参数）
  static Future<Map<String, dynamic>> getPostDetail(dynamic postId) async {
    int id;
    if (postId is int) {
      id = postId;
    } else if (postId is String) {
      id = int.tryParse(postId) ?? -1;
    } else {
      throw ArgumentError('postId must be int or String');
    }
    return getPostDetailWithStatus(id);
  }

  /// 获取帖子详情（带状态，使用 /api/post/{id} 端点）
  static Future<Map<String, dynamic>> getPostDetailWithStatus(
    int postId,
  ) async {
    return HttpClient.instance.get('/api/post/$postId');
  }

  /// 搜索帖子
  /// GET /posts/search?q=keyword&type=keyword|tag&sort=hot|new&page=1&pageSize=20
  static Future<Map<String, dynamic>> searchPosts({
    required String query,
    String type = 'keyword',
    String sort = 'hot',
    int page = 1,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/posts/search', queryParameters: {
      'q': query,
      'type': type,
      'sort': sort,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
  }

  /// 创建帖子
  static Future<Map<String, dynamic>> createPost({
    required String title,
    String? content,
    List<String>? media,
    required String mainDiscipline,
    String? doi,
    String? journal,
    int? year,
    List<String>? externalLinks,
    String? arxivId,
    List<String>? arxivAuthors,
    String? arxivPublishedDate,
    List<String>? arxivCategories,
    List<int>? references,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      if (media != null) 'media': media,
      'mainDiscipline': mainDiscipline,
      if (doi != null) 'doi': doi,
      if (journal != null) 'journal': journal,
      if (year != null) 'year': year,
      if (externalLinks != null) 'externalLinks': externalLinks,
      if (arxivId != null) 'arxivId': arxivId,
      if (arxivAuthors != null && arxivAuthors.isNotEmpty)
        'arxivAuthors': arxivAuthors,
      if (arxivPublishedDate != null) 'arxivPublishedDate': arxivPublishedDate,
      if (arxivCategories != null && arxivCategories.isNotEmpty)
        'arxivCategories': arxivCategories,
      if (references != null && references.isNotEmpty) 'references': references,
      if (status != null) 'status': status,
    };
    return HttpClient.instance.post('/posts', body: body);
  }

  /// 编辑帖子
  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String title,
    String? content,
    required List<String> media,
    required String mainDiscipline,
    String? doi,
    String? journal,
    int? year,
    List<String>? externalLinks,
    String? arxivId,
    List<String>? arxivAuthors,
    String? arxivPublishedDate,
    List<String>? arxivCategories,
    List<int>? references,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      'media': media,
      'mainDiscipline': mainDiscipline,
      if (doi != null) 'doi': doi,
      if (journal != null) 'journal': journal,
      if (year != null) 'year': year,
      if (externalLinks != null) 'externalLinks': externalLinks,
      if (arxivId != null) 'arxivId': arxivId,
      if (arxivAuthors != null && arxivAuthors.isNotEmpty)
        'arxivAuthors': arxivAuthors,
      if (arxivPublishedDate != null) 'arxivPublishedDate': arxivPublishedDate,
      if (arxivCategories != null && arxivCategories.isNotEmpty)
        'arxivCategories': arxivCategories,
      if (references != null && references.isNotEmpty) 'references': references,
      if (status != null) 'status': status,
    };
    return HttpClient.instance.put('/posts/$postId', body: body);
  }

  /// 删除帖子
  static Future<Map<String, dynamic>> deletePost(String postId) async {
    return HttpClient.instance.delete('/posts/$postId');
  }

  /// 用户主动保存为草稿
  static Future<Map<String, dynamic>> savePostAsDraft(String postId) async {
    return HttpClient.instance.post('/posts/$postId/save-draft');
  }

  /// 作者保存草稿（修改被下架的帖子）
  static Future<Map<String, dynamic>> saveDraft({
    required int postId,
    required String title,
    required String content,
    List<String>? media,
    List<String>? tags,
  }) async {
    return HttpClient.instance.post('/api/post/$postId/draft', body: {
      'title': title,
      'content': content,
      'media': media ?? [],
      'tags': tags ?? [],
    });
  }

  /// 作者提交审核
  static Future<Map<String, dynamic>> submitForAudit(int postId) async {
    return HttpClient.instance.post('/api/post/$postId/submit');
  }

  /// 查询作者的被下架帖子列表
  static Future<Map<String, dynamic>> getAuthorRemovedPosts({
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/api/post/removed', queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
  }
}
