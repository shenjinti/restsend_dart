import 'package:collection/collection.dart';
import 'types.dart';
import 'services.dart';
import 'utils.dart';

const int maxRecallSecs = 120;
const int messageBucketSize = 50;

/// Message store for a topic
class MessageStore {
  final ServicesApi services;
  final String topicId;
  final int bucketSize;
  final List<ChatLog> messages = [];
  DateTime? lastSync;
  Future<User?> Function(String userId)? getUser;

  MessageStore(this.services, this.topicId, [this.bucketSize = messageBucketSize]);

  /// Get messages from server or cache
  Future<Map<String, dynamic>> getMessages(int? lastSeq, int? limit) async {
    final cachedLogs = _getMessagesFromCache(lastSeq, limit ?? bucketSize);
    if (cachedLogs != null) {
      for (final log in cachedLogs) {
        switch (log.content?.type) {
          case 'update.extra':
          case 'recall':
            final oldLog = messages.firstWhereOrNull(
              (m) => m.chatId == log.content?.text,
            );
            if (oldLog != null) {
              cachedLogs.add(oldLog);
            }
            break;
        }
      }
      return {'logs': cachedLogs, 'hasMore': false};
    }

    final resp = await services.getChatLogsDesc(topicId, lastSeq, limit ?? bucketSize);
    final items = resp['items'] as List<dynamic>? ?? [];
    final logs = <ChatLog>[];

    for (final item in items) {
      final log = ChatLog.fromJson(item as Map<String, dynamic>);
      log.chatId = log.chatId ?? item['id'] as String?;
      log.isSentByMe = log.senderId == services.myId;
      log.createdAt = formatDate(log.createdAt) ?? DateTime.now();
      log.updatedAt = formatDate(log.updatedAt) ?? DateTime.now();
      log.status = logStatusReceived;

      logs.add(log);
    }

    updateMessages(logs);
    return {'logs': logs, 'hasMore': resp['hasMore'] as bool? ?? false};
  }

  List<ChatLog>? _getMessagesFromCache(int? lastSeq, int limit) {
    if (messages.isEmpty || lastSeq == null) return null;

    final idx = messages.indexWhere((m) => m.seq == lastSeq);
    if (idx == -1) return null;

    var startIdx = idx - limit + 1;
    if (startIdx < 0) return null;

    final logs = messages.sublist(startIdx, startIdx + limit);
    if (logs.isEmpty || logs.length < limit) return null;

    final startSeq = logs.last.seq;
    final endSeq = logs.first.seq;
    final queryDiff = endSeq - startSeq;

    if (queryDiff > limit) return null;

    return logs;
  }

  /// Update messages in store
  void updateMessages(List<ChatLog> items) {
    for (final log in items) {
      final idx = messages.indexWhere((m) => m.chatId == log.chatId);
      if (idx != -1) {
        messages[idx] = log;
      } else {
        messages.add(log);
      }
    }
    messages.sort((a, b) => a.compareSort(b));
  }

  /// Clear all messages
  void clearMessages() {
    messages.clear();
  }

  /// Delete message by chat ID
  void deleteMessage(String chatId) {
    messages.removeWhere((m) => m.chatId == chatId);
  }

  /// Get message by chat ID
  ChatLog? getMessageByChatId(String chatId) {
    return messages.firstWhereOrNull((m) => m.chatId == chatId);
  }
}

/// Client store for managing users, conversations, and messages
class ClientStore {
  final ServicesApi services;
  final Map<String, User> users = {};
  final Map<String, Conversation> conversations = {};
  final Map<String, Topic> topics = {};
  final Map<String, MessageStore> topicMessages = {};
  DateTime? lastSyncConversation;

  ClientStore(this.services);

  /// Get message store for topic
  MessageStore getMessageStore(String topicId, [int? bucketSize]) {
    var store = topicMessages[topicId];
    if (store != null) return store;

    store = MessageStore(services, topicId, bucketSize ?? messageBucketSize);
    store.getUser = (userId) => getUser(userId);
    topicMessages[topicId] = store;
    return store;
  }

  /// Get user info
  Future<User?> getUser(String userId, [int maxAge = 60000]) async {
    final user = users[userId];
    if (user != null && maxAge > 0) {
      if (user.cachedAt != null &&
          DateTime.now().difference(user.cachedAt!).inMilliseconds < maxAge) {
        return user;
      }
    }

    try {
      final info = await services.getUserInfo(userId);
      return updateUser(userId, info);
    } catch (e) {
      logger.warning('Failed to get user info: $e');
      return user;
    }
  }

  /// Get topic info
  Future<Topic?> getTopic(String topicId, [int maxAge = 60000]) async {
    final topic = topics[topicId];
    if (topic != null && maxAge > 0) {
      if (topic.cachedAt != null &&
          DateTime.now().difference(topic.cachedAt!).inMilliseconds < maxAge) {
        return topic;
      }
    }

    return await _buildTopic(topicId, topic);
  }

  Future<Topic> _buildTopic(String topicId, Topic? topic) async {
    final resp = await services.getTopic(topicId);
    topic = Topic.fromJson(resp as Map<String, dynamic>);
    topic.cachedAt = DateTime.now();

    if (topic.notice != null) {
      topic.notice!.updatedAt = formatDate(topic.notice!.updatedAt);
    }

    topics[topicId] = topic;
    return topic;
  }

  /// Get conversation
  Future<Conversation?> getConversation(String topicId, [int maxAge = 60000]) async {
    final conversation = conversations[topicId];
    if (conversation != null && maxAge > 0) {
      if (conversation.cachedAt != null &&
          DateTime.now().difference(conversation.cachedAt!).inMilliseconds <
              maxAge) {
        return conversation;
      }
    }

    return await _buildConversation(topicId, conversation);
  }

  Future<Conversation> _buildConversation(
      String topicId, Conversation? conversation) async {
    final resp = await services.getConversation(topicId);
    conversation = Conversation.fromJson(resp as Map<String, dynamic>);
    conversation.cachedAt = DateTime.now();
    conversations[topicId] = conversation;
    return conversation;
  }

  /// Update user info
  User updateUser(String userId, dynamic data) {
    User user;
    if (data is User) {
      user = data;
    } else {
      user = User.fromJson(data as Map<String, dynamic>);
    }

    if (user.id.isEmpty) {
      user.id = userId;
    }
    user.cachedAt = DateTime.now();
    users[userId] = user;
    return user;
  }

  /// Update conversation
  void updateConversation(Conversation conversation) {
    conversations[conversation.topicId!] = conversation;
  }

  /// Process incoming chat message
  Conversation? processIncoming(Topic topic, ChatLog logItem, bool hasRead) {
    topic.lastSeq = logItem.seq > topic.lastSeq ? logItem.seq : topic.lastSeq;

    if (logItem.chatId == null) {
      return null;
    }

    logItem.isSentByMe = logItem.senderId == services.myId;
    _saveIncomingLog(topic.id!, logItem);
    return _mergeChatLog(topic, logItem, hasRead);
  }

  void _saveIncomingLog(String topicId, ChatLog logItem) {
    final store = getMessageStore(topicId);
    ChatLog? oldLog;

    switch (logItem.content?.type) {
      case 'topic.join':
        if (logItem.senderId == services.myId) {
          store.clearMessages();
        }
        break;

      case 'recall':
        oldLog = store.getMessageByChatId(logItem.content!.text!);
        if (oldLog != null && !oldLog.recall) {
          final now = DateTime.now();
          if (now.difference(oldLog.createdAt!).inSeconds >= maxRecallSecs) {
            break;
          }
          if (oldLog.senderId != logItem.senderId) {
            break;
          }
          oldLog.recall = true;
          oldLog.content = Content()..type = 'recalled';
        }
        break;

      case 'update.extra':
        final extra = logItem.content?.extra;
        final updateChatId = logItem.content?.text;
        if (updateChatId != null) {
          oldLog = store.getMessageByChatId(updateChatId);
          if (oldLog != null) {
            oldLog.content?.extra = extra;
          }
        }
        break;
    }

    final pendingLog = store.getMessageByChatId(logItem.chatId!);
    if (pendingLog != null) {
      if (pendingLog.status == logStatusSending) {
        logItem.status = logStatusSent;
      }
    } else {
      logItem.status = logStatusReceived;
    }

    store.updateMessages([logItem]);
  }

  Conversation? _mergeChatLog(Topic topic, ChatLog logItem, bool hasRead) {
    final content = logItem.content;
    final prevConversation = conversations[topic.id];
    var conversation = Conversation.fromTopic(topic, logItem);

    if (prevConversation != null) {
      conversation.unread = prevConversation.unread;
      conversation.lastReadSeq = prevConversation.lastReadSeq;
      conversation.lastReadAt = prevConversation.lastReadAt;
      conversation.sticky = prevConversation.sticky;
      conversation.tags = prevConversation.tags;
      conversation.extra = prevConversation.extra;
      conversation.lastMessage = prevConversation.lastMessage;
      conversation.lastMessageAt = prevConversation.lastMessageAt;
      conversation.lastMessageSeq = prevConversation.lastMessageSeq;
      conversation.lastSenderId = prevConversation.lastSenderId;
    }

    switch (content?.type) {
      case 'topic.change.owner':
        conversation.ownerId = logItem.senderId;
        break;

      case 'conversation.update':
        conversation.updatedAt = logItem.createdAt;
        // Parse update fields
        break;

      case 'conversation.removed':
        getMessageStore(topic.id!).clearMessages();
        return null;

      case 'topic.update':
        // Parse topic update
        break;

      case 'update.extra':
        if (conversation.lastMessage != null &&
            conversation.lastMessageSeq == logItem.seq &&
            content != null) {
          conversation.lastMessage!.extra = content.extra;
        }
        break;
    }

    if (logItem.seq >= conversation.lastReadSeq &&
        logItem.readable &&
        logItem.chatId != null) {
      conversation.unread += 1;
    }

    if (logItem.seq > conversation.lastSeq) {
      conversation.lastMessage = content;
      conversation.lastSeq = logItem.seq;
      conversation.lastSenderId = logItem.senderId;
      conversation.lastMessageAt = logItem.createdAt;
      conversation.lastMessageSeq = logItem.seq;
      conversation.updatedAt = logItem.createdAt;
    }

    if (hasRead) {
      conversation.lastReadSeq = logItem.seq;
      conversation.lastReadAt = logItem.createdAt;
      conversation.unread = 0;
    }

    updateConversation(conversation);
    return conversation;
  }
}
