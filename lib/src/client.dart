import 'dart:io';
import 'connection.dart';
import 'services.dart';
import 'store.dart';
import 'types.dart';
import 'utils.dart';

/// Main client class that combines all functionality
class Client extends Connection {
  late final ServicesApi services;
  late final ClientStore store;

  Client(String? endpoint) : super(_normalizeEndpoint(endpoint)) {
    services = ServicesApi(_normalizeEndpoint(endpoint));
    store = ClientStore(services);

    handlers['typing'] = _onTyping;
    handlers['chat'] = _onChat;
    handlers['read'] = _onRead;
  }

  static String? _normalizeEndpoint(String? endpoint) {
    if (endpoint == null) return null;
    return endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;
  }

  Future<int?> _onTyping(String? topicId, String? senderId, ChatRequest req) async {
    if (topicId != null && senderId != null) {
      onTyping?.call(topicId, senderId);
    }
    return null;
  }

  Future<int?> _onChat(String? topicId, String? senderId, ChatRequest req) async {
    if (topicId == null) return null;

    final topic = await getTopic(topicId);
    if (topic == null) {
      logger.warning('Bad topic id: $topicId');
      return null;
    }

    if (req.attendeeProfile != null && req.attendee != null) {
      store.updateUser(req.attendee!, req.attendeeProfile!);
    }

    final logItem = ChatLog()
      ..seq = req.seq
      ..chatId = req.chatId
      ..senderId = req.attendee
      ..content = req.content
      ..createdAt = formatDate(req.createdAt) ?? DateTime.now()
      ..updatedAt = formatDate(req.createdAt) ?? DateTime.now();

    final response = onTopicMessage?.call(topic, logItem);
    final hasRead = response?.hasRead ?? false;

    if (hasRead) {
      doRead(topicId: topicId, lastSeq: logItem.seq);
    }

    final conversation = store.processIncoming(topic, logItem, hasRead);
    if (conversation != null) {
      onConversationUpdated?.call(conversation);
    } else if (logItem.content?.type == 'conversation.removed') {
      onConversationRemoved?.call(topicId);
    }

    return response?.code;
  }

  Future<int?> _onRead(String? topicId, String? senderId, ChatRequest req) async {
    if (topicId == null) return null;

    final topic = await getTopic(topicId);
    if (topic == null) {
      logger.warning('Bad topic id: $topicId');
      return null;
    }

    final conversation = Conversation.fromTopic(topic)..unread = 0;
    onConversationUpdated?.call(conversation);
    return null;
  }

  @override
  ChatLog? _addPendingToStore(ChatRequest req) {
    if (req.topicId == null) return null;

    final store = this.store.getMessageStore(req.topicId!);
    final logItem = ChatLog()
      ..chatId = req.chatId
      ..senderId = myId
      ..isSentByMe = true
      ..status = logStatusSending
      ..content = req.content
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    store.updateMessages([logItem]);
    return logItem;
  }

  /// Get current user ID
  String get myId => services.myId ?? '';

  /// Get auth token
  @override
  String? get token => services.authToken;

  /// Guest login
  Future<dynamic> guestLogin({required String guestId, Map<String, dynamic>? extra}) async {
    final resp = await services.guestLogin(guestId, extra: extra);
    super.token = services.authToken;
    await connect();
    return resp;
  }

  /// Login with username and password
  Future<dynamic> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final resp = await services.login(username, password, remember: remember);
    super.token = services.authToken;
    await connect();
    return resp;
  }

  /// Login with token
  Future<dynamic> loginWithToken({
    required String username,
    required String token,
  }) async {
    if (token.isEmpty) {
      throw Exception('Token not found');
    }
    if (username.isEmpty) {
      throw Exception('Username not found');
    }

    final resp = await services.loginWithToken(username, token);
    super.token = services.authToken;
    await connect();
    return resp;
  }

  /// Logout
  Future<void> logout() async {
    await services.logout();
    shutdown();
  }

  /// Begin syncing conversations
  /// [limit] - Maximum number of conversations per request
  /// [category] - Optional category filter for conversations
  void beginSyncConversations([int? limit, String? category]) {
    var syncAt = store.lastSyncConversation;

    // Emit cached conversations first
    for (final conversation in store.conversations.values) {
      onConversationUpdated?.call(conversation);
    }

    Future<void> doSync() async {
      final resp = await services.getChatList(
        syncAt?.toIso8601String(),
        limit ?? 100,
        category,
      );

      final items = resp['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return;

      for (final item in items) {
        final data = item as Map<String, dynamic>;
        
        // Use server-side unreadCount if available, otherwise calculate locally
        if (data.containsKey('unreadCount')) {
          data['unread'] = data['unreadCount'];
        } else {
          final lastMessageSeq = data['lastMessageSeq'] as int? ?? data['lastSeq'] as int? ?? 0;
          final lastReadSeq = data['lastReadSeq'] as int? ?? 0;
          var unread = lastMessageSeq - lastReadSeq;
          if (unread < 0) unread = 0;
          data['unread'] = unread;
        }
        
        final conversation = Conversation.fromJson(data);
        store.updateConversation(conversation);
        onConversationUpdated?.call(conversation);
      }

      syncAt = DateTime.tryParse(resp['updatedAt'] as String? ?? '');
      if (resp['hasMore'] == true) {
        await doSync();
      }
    }

    doSync().then((_) {
      store.lastSyncConversation = syncAt;
      logger.info('Sync conversations completed');
    }).catchError((e) {
      logger.severe('Sync conversations failed: $e');
    });
  }

  /// Sync chat logs
  Future<Map<String, dynamic>> syncChatLogs({
    required String topicId,
    int? lastSeq,
    int? limit,
  }) async {
    final conversation = await getConversation(topicId);
    if (conversation == null) {
      throw Exception('Conversation not found');
    }

    final msgStore = store.getMessageStore(conversation.topicId!);
    return await msgStore.getMessages(
      lastSeq ?? conversation.lastSeq,
      limit,
    );
  }

  /// Try to chat with user
  Future<Conversation?> tryChatWithUser(User user) async {
    final topicData = await services.chatWithUser(user.id);
    if (topicData == null) return null;

    final topic = Topic.fromJson(topicData as Map<String, dynamic>);
    final conversation = Conversation.fromTopic(topic);

    if (conversation.unread > 0) {
      doRead(topicId: conversation.topicId!, lastSeq: conversation.lastSeq);
    }

    if ((conversation.name == null || conversation.name!.isEmpty) && !conversation.multiple) {
      conversation.name = user.displayName;
    }

    onConversationUpdated?.call(conversation);
    return conversation;
  }

  /// Remove conversation
  Future<dynamic> removeConversation(String topicId) async {
    final resp = await services.removeChat(topicId);
    onConversationRemoved?.call(topicId);
    return resp;
  }

  /// Set conversation as read
  Future<void> setConversationRead(Conversation conversation) async {
    if (conversation.unread > 0) {
      conversation.unread = 0;
      await doRead(topicId: conversation.topicId!, lastSeq: conversation.lastSeq);
    }
  }

  /// Mark conversation as unread
  Future<void> markConversationUnread(String topicId) async {
    final conversation = await store.getConversation(topicId);
    if (conversation != null && conversation.unread == 0) {
      conversation.unread = 1;
      store.updateConversation(conversation);
      onConversationUpdated?.call(conversation);
    }
    await services.markConversationUnread(topicId);
  }

  /// Get topic
  Future<Topic?> getTopic(String topicId) async {
    return await store.getTopic(topicId);
  }

  /// Get conversation
  Future<Conversation?> getConversation(String topicId) async {
    return await store.getConversation(topicId);
  }

  /// Get topic admins
  Future<List<User>> getTopicAdmins(String topicId) async {
    final topic = await getTopic(topicId);
    if (topic == null) return [];

    final admins = <User>[];
    for (final adminId in topic.admins) {
      final user = await getUser(adminId);
      if (user != null) admins.add(user);
    }
    return admins;
  }

  /// Create topic
  Future<List<dynamic>> createTopic({
    required String name,
    String? icon,
    required List<String> members,
    String? kind,
  }) async {
    return await services.createTopic(name, icon, members, kind);
  }

  /// Get topic members
  Future<dynamic> getTopicMembers({
    required String topicId,
    String? updatedAt,
    int? limit,
  }) async {
    return await services.syncTopicMembers(topicId, updatedAt, limit);
  }

  /// Update topic
  Future<List<dynamic>> updateTopic({
    required String topicId,
    String? name,
    String? icon,
    String? kind,
  }) async {
    return await services.updateTopic(topicId, name, icon, kind);
  }

  /// Update topic notice
  Future<List<dynamic>> updateTopicNotice({
    required String topicId,
    required String text,
  }) async {
    return await services.updateTopicNotice(topicId, text);
  }

  /// Silent topic
  Future<dynamic> silentTopic({
    required String topicId,
    required String duration,
  }) async {
    return await services.silentTopic(topicId, duration);
  }

  /// Silent topic member
  Future<dynamic> silentTopicMember({
    required String topicId,
    required String userId,
    required String duration,
  }) async {
    return await services.silentTopicMember(topicId, userId, duration);
  }

  /// Dismiss topic
  Future<List<dynamic>> dismissTopic(String topicId) async {
    return await services.dismissTopic(topicId);
  }

  /// Join topic
  Future<List<dynamic>> joinTopic({
    required String topicId,
    String? source,
    String? message,
    String? memo,
  }) async {
    return await services.joinTopic(topicId, source, message, memo);
  }

  /// Remove topic member
  Future<dynamic> removeTopicMember({
    required String topicId,
    required String userId,
  }) async {
    return await services.removeTopicMember(topicId, userId);
  }

  /// Delete message
  Future<dynamic> deleteMessage({
    required String topicId,
    required String chatId,
    bool sync = true,
  }) async {
    store.getMessageStore(topicId).deleteMessage(chatId);
    if (sync) {
      return await services.deleteMessage(topicId, chatId);
    }
  }

  /// Get user info
  Future<User?> getUser(String userId) async {
    return await store.getUser(userId);
  }

  /// Set user block status
  Future<List<dynamic>> setUserBlock({
    required String userId,
    required bool blocked,
  }) async {
    if (blocked) {
      return await services.setBlocked(userId);
    } else {
      return await services.unsetBlocked(userId);
    }
  }

  /// Allow chat with user
  Future<dynamic> allowChatWithUser({required String userId}) async {
    return await services.allowChatWithUser(userId);
  }

  /// Upload file
  Future<UploadResult> uploadFile({
    required File file,
    required String topicId,
    bool isPrivate = false,
  }) async {
    return await services.uploadFile(file, topicId, isPrivate);
  }

  /// Send text message (convenience method)
  Future<ChatRequest> sendText({
    required String topicId,
    required String text,
    List<String>? mentions,
    String? reply,
  }) async {
    return await doSendText(
      topicId: topicId,
      text: text,
      mentions: mentions,
      reply: reply,
    );
  }

  /// Send image message (convenience method)
  Future<ChatRequest> sendImage({
    required String topicId,
    required String urlOrData,
    int? size,
    List<String>? mentions,
    String? reply,
  }) async {
    return await doSendImage(
      topicId: topicId,
      urlOrData: urlOrData,
      size: size,
      mentions: mentions,
      reply: reply,
    );
  }

  /// Send file message (convenience method)
  Future<ChatRequest> sendFile({
    required String topicId,
    required String urlOrData,
    required String filename,
    required int size,
    List<String>? mentions,
    String? reply,
  }) async {
    return await doSendFile(
      topicId: topicId,
      urlOrData: urlOrData,
      filename: filename,
      size: size,
      mentions: mentions,
      reply: reply,
    );
  }

  /// Recall message (convenience method)
  Future<ChatRequest> recallMessage({
    required String topicId,
    required String chatId,
  }) async {
    return await doRecall(topicId: topicId, chatId: chatId);
  }
}
