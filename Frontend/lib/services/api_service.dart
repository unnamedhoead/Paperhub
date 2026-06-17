import 'dart:typed_data';

import '../config/app_env.dart';
import 'api/admin_api.dart';
import 'api/auth_api.dart';
import 'api/chat_api.dart';
import 'api/comment_api.dart';
import 'api/history_api.dart';
import 'api/interaction_api.dart';
import 'api/post_api.dart';
import 'api/report_api.dart';
import 'api/user_api.dart';
import 'core/http_client.dart';

export 'api/admin_api.dart';
export 'api/auth_api.dart';
export 'api/chat_api.dart';
export 'api/comment_api.dart';
export 'api/history_api.dart';
export 'api/interaction_api.dart';
export 'api/post_api.dart';
export 'api/report_api.dart';
export 'api/user_api.dart';

final String baseUrl = AppEnv.apiBaseUrl;

class ApiService {
  // 全局 401 错误回调（当刷新 token 失败时调用）
  static void Function()? _onAuthFailed;

  static set onAuthFailed(void Function()? callback) {
    _onAuthFailed = callback;
    HttpClient.instance.onAuthFailed = callback;
  }

  static void Function()? get onAuthFailed => _onAuthFailed;

  // ==================== Auth ====================
  static Future<Map<String, dynamic>> sendVerification(String email) =>
      AuthApi.sendVerification(email);
  static Future<Map<String, dynamic>> verifyCode(String email, String code) =>
      AuthApi.verifyCode(email, code);
  static Future<Map<String, dynamic>> register(String email, String password) =>
      AuthApi.register(email, password);
  static Future<Map<String, dynamic>> login(String email, String password) =>
      AuthApi.login(email, password);
  static Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      AuthApi.requestPasswordReset(email);
  static Future<Map<String, dynamic>> resetPassword(
          String email, String code, String newPassword) =>
      AuthApi.resetPassword(email, code, newPassword);
  static Future<Map<String, dynamic>> refreshToken() =>
      AuthApi.refreshToken();
  static Future<void> logout() => AuthApi.logout();

  // ==================== User ====================
  static Future<Map<String, dynamic>> getCurrentUserProfile() =>
      UserApi.getCurrentUserProfile();
  static Future<Map<String, dynamic>> getUserProfile(String userId) =>
      UserApi.getUserProfile(userId);
  static Future<Map<String, dynamic>> getPrivacySettings() =>
      UserApi.getPrivacySettings();
  static Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    String? bio,
    List<String>? researchDirections,
    String? avatarUrl,
    String? backgroundImage,
  }) =>
      UserApi.updateProfile(
        displayName: displayName,
        bio: bio,
        researchDirections: researchDirections,
        avatarUrl: avatarUrl,
        backgroundImage: backgroundImage,
      );
  static Future<Map<String, dynamic>> updatePrivacySettings({
    required bool hideFollowing,
    required bool hideFollowers,
    required bool publicFavorites,
  }) =>
      UserApi.updatePrivacySettings(
        hideFollowing: hideFollowing,
        hideFollowers: hideFollowers,
        publicFavorites: publicFavorites,
      );
  static Future<Map<String, dynamic>> uploadAvatarBytes(
          Uint8List data, String fileName) =>
      UserApi.uploadAvatarBytes(data, fileName);
  static Future<Map<String, dynamic>> uploadBackgroundBytes(
          Uint8List data, String fileName) =>
      UserApi.uploadBackgroundBytes(data, fileName);
  static Future<Map<String, dynamic>> searchUsers({
    required String query,
    String type = 'all',
    int page = 0,
    int pageSize = 20,
  }) =>
      UserApi.searchUsers(
        query: query,
        type: type,
        page: page,
        pageSize: pageSize,
      );
  static Future<Map<String, dynamic>> getUserPosts(String userId,
          {int page = 1, int pageSize = 10}) =>
      UserApi.getUserPosts(userId, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getUserFavorites(String userId,
          {int page = 1, int pageSize = 10}) =>
      UserApi.getUserFavorites(userId, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getUserDrafts(
          {int page = 1, int pageSize = 20}) =>
      UserApi.getUserDrafts(page: page, pageSize: pageSize);

  // ==================== Post ====================
  static Future<Map<String, dynamic>> getPosts(
          {int page = 1, int pageSize = 20, String? disciplineTag}) =>
      PostApi.getPosts(
          page: page, pageSize: pageSize, disciplineTag: disciplineTag);
  static Future<Map<String, dynamic>> getRecommendedPosts(
          {int page = 1, int pageSize = 20}) =>
      PostApi.getRecommendedPosts(page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getFollowingPosts(
          {int page = 1, int pageSize = 20}) =>
      PostApi.getFollowingPosts(page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getPost(String postId) =>
      PostApi.getPost(postId);
  static Future<Map<String, dynamic>> getPostDetail(dynamic postId) =>
      PostApi.getPostDetail(postId);
  static Future<Map<String, dynamic>> getPostDetailWithStatus(int postId) =>
      PostApi.getPostDetailWithStatus(postId);
  static Future<Map<String, dynamic>> searchPosts({
    required String query,
    String type = 'keyword',
    String sort = 'hot',
    int page = 1,
    int pageSize = 20,
  }) =>
      PostApi.searchPosts(
        query: query,
        type: type,
        sort: sort,
        page: page,
        pageSize: pageSize,
      );
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
  }) =>
      PostApi.createPost(
        title: title,
        content: content,
        media: media,
        mainDiscipline: mainDiscipline,
        doi: doi,
        journal: journal,
        year: year,
        externalLinks: externalLinks,
        arxivId: arxivId,
        arxivAuthors: arxivAuthors,
        arxivPublishedDate: arxivPublishedDate,
        arxivCategories: arxivCategories,
        references: references,
        status: status,
      );
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
  }) =>
      PostApi.updatePost(
        postId: postId,
        title: title,
        content: content,
        media: media,
        mainDiscipline: mainDiscipline,
        doi: doi,
        journal: journal,
        year: year,
        externalLinks: externalLinks,
        arxivId: arxivId,
        arxivAuthors: arxivAuthors,
        arxivPublishedDate: arxivPublishedDate,
        arxivCategories: arxivCategories,
        references: references,
        status: status,
      );
  static Future<Map<String, dynamic>> deletePost(String postId) =>
      PostApi.deletePost(postId);
  static Future<Map<String, dynamic>> savePostAsDraft(String postId) =>
      PostApi.savePostAsDraft(postId);
  static Future<Map<String, dynamic>> saveDraft({
    required int postId,
    required String title,
    required String content,
    List<String>? media,
    List<String>? tags,
  }) =>
      PostApi.saveDraft(
        postId: postId,
        title: title,
        content: content,
        media: media,
        tags: tags,
      );
  static Future<Map<String, dynamic>> submitForAudit(int postId) =>
      PostApi.submitForAudit(postId);
  static Future<Map<String, dynamic>> getAuthorRemovedPosts(
          {int page = 0, int pageSize = 20}) =>
      PostApi.getAuthorRemovedPosts(page: page, pageSize: pageSize);

  // ==================== Interaction ====================
  static Future<Map<String, dynamic>> likePost(String postId,
          {String? authToken}) =>
      InteractionApi.likePost(postId, authToken: authToken);
  static Future<Map<String, dynamic>> unlikePost(String postId,
          {String? authToken}) =>
      InteractionApi.unlikePost(postId, authToken: authToken);
  static Future<Map<String, dynamic>> likeComment(
          String postId, String commentId, {String? authToken}) =>
      InteractionApi.likeComment(postId, commentId, authToken: authToken);
  static Future<Map<String, dynamic>> unlikeComment(
          String postId, String commentId, {String? authToken}) =>
      InteractionApi.unlikeComment(postId, commentId, authToken: authToken);
  static Future<Map<String, dynamic>> favoritePost(String postId) =>
      InteractionApi.favoritePost(postId);
  static Future<Map<String, dynamic>> unfavoritePost(String postId) =>
      InteractionApi.unfavoritePost(postId);
  static Future<Map<String, dynamic>> followUser(String userId) =>
      InteractionApi.followUser(userId);
  static Future<Map<String, dynamic>> unfollowUser(String userId) =>
      InteractionApi.unfollowUser(userId);
  static Future<Map<String, dynamic>> getFollowers(String userId,
          {int page = 0, int pageSize = 20}) =>
      InteractionApi.getFollowers(userId, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getFollowing(String userId,
          {int page = 0, int pageSize = 20}) =>
      InteractionApi.getFollowing(userId, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getMutualFollowers(String userId,
          {int page = 0, int pageSize = 20}) =>
      InteractionApi.getMutualFollowers(userId, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getUnreadNotificationCount() =>
      InteractionApi.getUnreadNotificationCount();
  static Future<Map<String, dynamic>> getLikesAndFavorites(
          {int page = 0, int pageSize = 20}) =>
      InteractionApi.getLikesAndFavorites(page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getFollows(
          {int page = 0, int pageSize = 20}) =>
      InteractionApi.getFollows(page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getCommentsAndMentions(
          {int page = 0, int pageSize = 20}) =>
      InteractionApi.getCommentsAndMentions(page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> markNotificationAsRead(
          String notificationId) =>
      InteractionApi.markNotificationAsRead(notificationId);
  static Future<Map<String, dynamic>> markAllNotificationsAsReadByTypes(
          List<String> types) =>
      InteractionApi.markAllNotificationsAsReadByTypes(types);
  static Future<Map<String, dynamic>> createNotification(
          Map<String, dynamic> payload, {String? authToken}) =>
      InteractionApi.createNotification(payload, authToken: authToken);

  // ==================== Comment ====================
  static Future<Map<String, dynamic>> getComments(String postId,
          {int page = 1, int pageSize = 20, String sort = 'time'}) =>
      CommentApi.getComments(postId,
          page: page, pageSize: pageSize, sort: sort);
  static Future<Map<String, dynamic>> createComment(
          String postId, String content,
          {String? parentId,
          String? replyToId,
          List<String>? mentionIds}) =>
      CommentApi.createComment(postId, content,
          parentId: parentId,
          replyToId: replyToId,
          mentionIds: mentionIds);
  static Future<Map<String, dynamic>> updateComment(
          String postId, String commentId, String content) =>
      CommentApi.updateComment(postId, commentId, content);
  static Future<Map<String, dynamic>> deleteComment(
          String postId, String commentId) =>
      CommentApi.deleteComment(postId, commentId);
  static Future<Map<String, dynamic>> reportComment(
          String postId, String commentId, String reason) =>
      CommentApi.reportComment(postId, commentId, reason);

  // ==================== Report ====================
  static Future<Map<String, dynamic>> reportPost(
          {required int postId, required String description}) =>
      ReportApi.reportPost(postId: postId, description: description);
  static Future<Map<String, dynamic>> reportUser(
          String userId, String reason) =>
      ReportApi.reportUser(userId, reason);

  // ==================== Chat ====================
  static Future<Map<String, dynamic>> getConversations() =>
      ChatApi.getConversations();
  static Future<Map<String, dynamic>> createOrGetConversation(
          String targetUserId) =>
      ChatApi.createOrGetConversation(targetUserId);
  static Future<Map<String, dynamic>> getConversationMessages(
          String conversationId,
          {int page = 0, int pageSize = 100}) =>
      ChatApi.getConversationMessages(conversationId,
          page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> sendMessage(
          String conversationId, String content,
          {String type = 'TEXT',
          String? fileUrl,
          String? fileName,
          int? fileSize}) =>
      ChatApi.sendMessage(conversationId, content,
          type: type,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize);
  static Future<Map<String, dynamic>> sendMessageWithMedia(
          String conversationId, List<String> mediaUrls,
          {String type = 'IMAGE',
          String content = '',
          String? fileName,
          int? fileSize}) =>
      ChatApi.sendMessageWithMedia(conversationId, mediaUrls,
          type: type,
          content: content,
          fileName: fileName,
          fileSize: fileSize);
  static Future<Map<String, dynamic>> markConversationAsRead(
          String conversationId) =>
      ChatApi.markConversationAsRead(conversationId);
  static Future<Map<String, dynamic>> uploadChatFile(
          List<int> fileBytes, String fileName) =>
      ChatApi.uploadChatFile(fileBytes, fileName);

  // ==================== History ====================
  static Future<Map<String, dynamic>> getBrowseHistory({int limit = 50}) =>
      HistoryApi.getBrowseHistory(limit: limit);
  static Future<Map<String, dynamic>> addBrowseHistory(
          {required String postId, required String title}) =>
      HistoryApi.addBrowseHistory(postId: postId, title: title);
  static Future<Map<String, dynamic>> deleteBrowseHistory(String postId) =>
      HistoryApi.deleteBrowseHistory(postId);
  static Future<Map<String, dynamic>> clearBrowseHistory() =>
      HistoryApi.clearBrowseHistory();
  static Future<Map<String, dynamic>> getSearchHistory({int limit = 20}) =>
      HistoryApi.getSearchHistory(limit: limit);
  static Future<Map<String, dynamic>> addSearchHistory(
          {required String keyword, required String searchType}) =>
      HistoryApi.addSearchHistory(keyword: keyword, searchType: searchType);
  static Future<Map<String, dynamic>> deleteSearchHistory(String id) =>
      HistoryApi.deleteSearchHistory(id);
  static Future<Map<String, dynamic>> clearSearchHistory() =>
      HistoryApi.clearSearchHistory();
  static Future<Map<String, dynamic>> getRecentSearchKeywords(
          {int limit = 50}) =>
      HistoryApi.getRecentSearchKeywords(limit: limit);
  static Future<Map<String, dynamic>> getHotSearches(
          {int limit = 20, String? type}) =>
      HistoryApi.getHotSearches(limit: limit, type: type);

  // ==================== Admin ====================
  static Future<Map<String, dynamic>> adminSearchUsers(
          {String? query, String? status, int page = 0, int pageSize = 20}) =>
      AdminApi.adminSearchUsers(
          query: query, status: status, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> getAuditUsers() =>
      AdminApi.getAuditUsers();
  static Future<Map<String, dynamic>> adminApproveUser(String userId) =>
      AdminApi.adminApproveUser(userId);
  static Future<Map<String, dynamic>> adminRejectUser(String userId,
          {required String action, String? reason}) =>
      AdminApi.adminRejectUser(userId, action: action, reason: reason);
  static Future<Map<String, dynamic>> adminHidePost(String postId) =>
      AdminApi.adminHidePost(postId);
  static Future<Map<String, dynamic>> adminSearchPosts(
          {String? query,
          String? author,
          int page = 0,
          int pageSize = 20}) =>
      AdminApi.adminSearchPosts(
          query: query, author: author, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> adminGetNotices(
          {String? query, int page = 0, int pageSize = 20}) =>
      AdminApi.adminGetNotices(
          query: query, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> adminCreateNotice(
          {required String title,
          String? content,
          String? attachmentsJson,
          bool published = true}) =>
      AdminApi.adminCreateNotice(
          title: title,
          content: content,
          attachmentsJson: attachmentsJson,
          published: published);
  static Future<Map<String, dynamic>> adminUpdateNotice(
          {required String id,
          required String title,
          String? content,
          String? attachmentsJson,
          bool published = true}) =>
      AdminApi.adminUpdateNotice(
          id: id,
          title: title,
          content: content,
          attachmentsJson: attachmentsJson,
          published: published);
  static Future<Map<String, dynamic>> adminDeleteNotice(String id) =>
      AdminApi.adminDeleteNotice(id);
  static Future<Map<String, dynamic>> adminGetReports(
          {String? query,
          String? status,
          String? targetType,
          int page = 0,
          int pageSize = 20}) =>
      AdminApi.adminGetReports(
          query: query,
          status: status,
          targetType: targetType,
          page: page,
          pageSize: pageSize);
  static Future<Map<String, dynamic>> adminHandleReport(
          {required String id,
          required String action,
          String? note}) =>
      AdminApi.adminHandleReport(id: id, action: action, note: note);
  static Future<Map<String, dynamic>> adminCreateApplication(
          {required String candidateUserId, required String reason}) =>
      AdminApi.adminCreateApplication(
          candidateUserId: candidateUserId, reason: reason);
  static Future<Map<String, dynamic>> adminGetApplications(
          {String? status, int page = 0, int pageSize = 20}) =>
      AdminApi.adminGetApplications(
          status: status, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> adminApproveApplication(String id) =>
      AdminApi.adminApproveApplication(id);
  static Future<Map<String, dynamic>> adminRejectApplication(String id) =>
      AdminApi.adminRejectApplication(id);
  static Future<Map<String, dynamic>> adminGrantAdmin(String userId) =>
      AdminApi.adminGrantAdmin(userId);
  static Future<Map<String, dynamic>> adminRevokeAdmin(String userId) =>
      AdminApi.adminRevokeAdmin(userId);
  static Future<Map<String, dynamic>> adminBanUser(String userId) =>
      AdminApi.adminBanUser(userId);
  static Future<Map<String, dynamic>> adminUnbanUser(String userId) =>
      AdminApi.adminUnbanUser(userId);
  static Future<Map<String, dynamic>> adminMuteUser(String userId,
          {required int duration, required String unit}) =>
      AdminApi.adminMuteUser(userId, duration: duration, unit: unit);
  static Future<Map<String, dynamic>> adminUnmuteUser(String userId) =>
      AdminApi.adminUnmuteUser(userId);
  static Future<Map<String, dynamic>> adminGetReportPosts(
          {String? status, int page = 0, int pageSize = 20}) =>
      AdminApi.adminGetReportPosts(
          status: status, page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> adminRemovePost(
          {required int reportId, required String reason}) =>
      AdminApi.adminRemovePost(reportId: reportId, reason: reason);
  static Future<Map<String, dynamic>> adminIgnoreReport(
          {required int reportId, String? reason}) =>
      AdminApi.adminIgnoreReport(reportId: reportId, reason: reason);
  static Future<Map<String, dynamic>> adminApprovePost(int postId) =>
      AdminApi.adminApprovePost(postId);
  static Future<Map<String, dynamic>> adminRejectPost(
          {required int postId, required String reason}) =>
      AdminApi.adminRejectPost(postId: postId, reason: reason);
  static Future<Map<String, dynamic>> adminGetAuditPosts(
          {int page = 0, int pageSize = 20}) =>
      AdminApi.adminGetAuditPosts(page: page, pageSize: pageSize);
  static Future<Map<String, dynamic>> adminCountPendingReports() =>
      AdminApi.adminCountPendingReports();
  static Future<Map<String, dynamic>> adminApproveAuditPost(
          {required int postId}) =>
      AdminApi.adminApproveAuditPost(postId: postId);
  static Future<Map<String, dynamic>> adminRejectAuditPost(
          {required int postId, required String reason}) =>
      AdminApi.adminRejectAuditPost(postId: postId, reason: reason);
}
