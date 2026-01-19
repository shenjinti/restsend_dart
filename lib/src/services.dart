import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'backend.dart';
import 'types.dart';

/// Services API client
class ServicesApi {
  String? myId;
  String? authToken;
  final String endpoint;

  ServicesApi(String? endpoint)
      : endpoint = endpoint ?? '',
        myId = null,
        authToken = null;

  /// Get backend API instance
  BackendApi get backend => BackendApi(authToken);

  /// User logout
  Future<dynamic> logout() async {
    return await backend.get('$endpoint/auth/logout');
  }

  /// User registration
  Future<dynamic> signup(String email, String password,
      {bool remember = true}) async {
    final resp = await backend
        .post('$endpoint/auth/register', {'email': email, 'password': password, 'remember': remember});
    return resp;
  }

  /// Guest login
  Future<dynamic> guestLogin(String guestId,
      {bool remember = true, Map<String, dynamic>? extra}) async {
    final resp = await backend.post('$endpoint/api/guest/login',
        {'guestId': guestId, 'remember': remember, 'extra': extra});
    authToken = resp['token'] as String?;
    myId = resp['email'] as String?;
    return resp;
  }

  /// User login
  Future<dynamic> login(String email, String password,
      {bool remember = true}) async {
    final resp = await backend.post('$endpoint/auth/login',
        {'email': email, 'password': password, 'remember': remember});
    authToken = resp['token'] as String?;
    myId = resp['email'] as String?;
    return resp;
  }

  /// Login with token
  Future<dynamic> loginWithToken(String email, String token) async {
    final resp = await backend.post(
        '$endpoint/auth/login', {'email': email, 'token': token, 'remember': true});
    authToken = resp['token'] as String?;
    myId = email;
    return resp;
  }

  /// Create chat with user
  Future<dynamic> chatWithUser(String userId) async {
    return await backend.post('$endpoint/api/topic/create/$userId');
  }

  /// Set user as blocked
  Future<List<dynamic>> setBlocked(String userId) async {
    final resp = await backend.post('$endpoint/api/block/$userId');
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Unset user as blocked
  Future<List<dynamic>> unsetBlocked(String userId) async {
    final resp = await backend.post('$endpoint/api/unblock/$userId');
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Get chat list
  Future<dynamic> getChatList(String? updatedAt, int? limit, [String? category]) async {
    final params = <String, dynamic>{'updatedAt': updatedAt, 'limit': limit};
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    return await backend.post('$endpoint/api/chat/list', params);
  }

  /// Mark conversation as unread
  Future<dynamic> markConversationUnread(String topicId) async {
    return await backend.post('$endpoint/api/chat/unread/$topicId');
  }

  /// Remove chat from list
  Future<dynamic> removeChat(String topicId) async {
    return await backend.post('$endpoint/api/chat/remove/$topicId');
  }

  /// Get chat logs in descending order
  Future<dynamic> getChatLogsDesc(String topicId, int? lastSeq, int? limit) async {
    return await backend.post(
        '$endpoint/api/chat/sync/$topicId', {'lastSeq': lastSeq, 'limit': limit});
  }

  /// Get topic information
  Future<dynamic> getTopic(String topicId) async {
    return await backend.post('$endpoint/api/topic/info/$topicId');
  }

  /// Get conversation information
  Future<dynamic> getConversation(String topicId) async {
    return await backend.post('$endpoint/api/chat/info/$topicId');
  }

  /// Sync topic members
  Future<dynamic> syncTopicMembers(
      String topicId, String? updatedAt, int? limit) async {
    return await backend.post('$endpoint/api/topic/members/$topicId',
        {'updatedAt': updatedAt, 'limit': limit});
  }

  /// Create topic
  Future<List<dynamic>> createTopic(
      String name, String? icon, List<String> members, String? kind) async {
    final resp = await backend.post('$endpoint/api/topic/create',
        {'name': name, 'icon': icon, 'members': members, 'kind': kind});
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Update topic
  Future<List<dynamic>> updateTopic(
      String topicId, String? name, String? icon, String? kind) async {
    final resp = await backend.post('$endpoint/api/topic/admin/update/$topicId',
        {'name': name, 'icon': icon, 'kind': kind});
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Join topic
  Future<List<dynamic>> joinTopic(
      String topicId, String? source, String? message, String? memo) async {
    final resp = await backend.post('$endpoint/api/topic/knock/$topicId',
        {'source': source, 'message': message, 'memo': memo});
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Get topic apply list
  Future<List<dynamic>> getTopicApplyList(Map<String, dynamic> params) async {
    final resp =
        await backend.post('$endpoint/api/topic/admin/list_knock/$params');
    return resp as List<dynamic>? ?? [];
  }

  /// Get all topic apply list
  Future<List<dynamic>> getAllTopicApplyList() async {
    final resp =
        await backend.post('$endpoint/api/topic/admin/list_knock_all/');
    return resp as List<dynamic>? ?? [];
  }

  /// Accept topic application
  Future<List<dynamic>> acceptTopic(Map<String, dynamic> params) async {
    final topicId = params['topicId'];
    final userId = params['userId'];
    final resp = await backend.post(
        '$endpoint/api/topic/admin/knock/accept/$topicId/$userId', params);
    return resp as List<dynamic>? ?? [];
  }

  /// Dismiss topic
  Future<List<dynamic>> dismissTopic(String topicId) async {
    final resp = await backend
        .post('$endpoint/api/topic/dismiss/$topicId', {'topicId': topicId});
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Update topic notice
  Future<List<dynamic>> updateTopicNotice(String topicId, String text) async {
    final resp = await backend
        .post('$endpoint/api/topic/admin/notice/$topicId', {'text': text});
    return resp['items'] as List<dynamic>? ?? [];
  }

  /// Get user info
  Future<User> getUserInfo(String userId) async {
    try {
      final resp = await backend.post('$endpoint/api/profile/$userId');
      return User.fromJson(resp as Map<String, dynamic>);
    } catch (error) {
      return User(userId);
    }
  }

  /// Silent topic
  Future<dynamic> silentTopic(String topicId, String duration) async {
    return await backend.post(
        '$endpoint/api/topic/admin/silent_topic/$topicId', {'duration': duration});
  }

  /// Silent topic member
  Future<dynamic> silentTopicMember(
      String topicId, String userId, String duration) async {
    return await backend.post(
        '$endpoint/api/topic/admin/silent/$topicId/$userId', {'duration': duration});
  }

  /// Remove topic member
  Future<dynamic> removeTopicMember(String topicId, String userId) async {
    return await backend
        .post('$endpoint/api/topic/admin/kickout/$topicId/$userId');
  }

  /// Allow chat with user
  Future<dynamic> allowChatWithUser(String userId) async {
    return await backend
        .post('$endpoint/api/relation/$userId', {'chatAllowed': true});
  }

  /// Upload file
  Future<UploadResult> uploadFile(
      File file, String topicId, bool isPrivate) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$endpoint/api/attachment/upload'),
    );

    if (authToken != null && authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    request.fields['topicId'] = topicId;
    request.fields['private'] = isPrivate.toString();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final result = await handleResult(response);

    return UploadResult.fromJson(result as Map<String, dynamic>);
  }

  /// Delete message
  Future<dynamic> deleteMessage(String topicId, String chatId) async {
    return await backend.post('$endpoint/api/chat/remove_messages/$topicId',
        {'ids': [chatId]});
  }

  /// Update conversation settings
  Future<dynamic> updateConversation(
      String topicId, ConversationUpdateFields fields) async {
    return await backend.post(
        '$endpoint/api/chat/update/$topicId', fields.toJson());
  }
}
