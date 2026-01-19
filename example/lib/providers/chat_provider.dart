import 'package:flutter/foundation.dart';
import 'package:restsend_dart/restsend_dart.dart';

class ChatProvider extends ChangeNotifier {
  Client? _client;
  List<Conversation> _conversations = [];
  Map<String, List<ChatLog>> _messages = {};
  String? _currentTopicId;
  bool _isConnected = false;

  Client? get client => _client;
  List<Conversation> get conversations => _conversations;
  String? get currentTopicId => _currentTopicId;
  bool get isConnected => _isConnected;

  List<ChatLog> getMessages(String topicId) {
    return _messages[topicId] ?? [];
  }

  Future<void> init(String endpoint) async {
    _client = Client(endpoint);
    
    // Setup callbacks
    _client!.onConnected = () {
      _isConnected = true;
      notifyListeners();
    };

    _client!.onNetBroken = (reason) {
      _isConnected = false;
      notifyListeners();
    };

    _client!.onConversationUpdated = (conversation) {
      final index = _conversations.indexWhere((c) => c.topicId == conversation.topicId);
      if (index >= 0) {
        _conversations[index] = conversation;
      } else {
        _conversations.add(conversation);
      }
      _conversations.sort((a, b) => a.compareSort(b));
      notifyListeners();
    };

    _client!.onConversationRemoved = (topicId) {
      _conversations.removeWhere((c) => c.topicId == topicId);
      _messages.remove(topicId);
      notifyListeners();
    };

    _client!.onTopicMessage = (topic, message) {
      if (!_messages.containsKey(topic.id)) {
        _messages[topic.id!] = [];
      }
      _messages[topic.id!]!.add(message);
      _messages[topic.id!]!.sort((a, b) => a.compareSort(b));
      notifyListeners();
      return OnMessageResponse(hasRead: _currentTopicId == topic.id, code: 200);
    };
  }

  Future<void> guestLogin(String guestId) async {
    if (_client == null) return;
    
    try {
      await _client!.guestLogin(guestId: guestId);
      _client!.beginSyncConversations();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> login(String username, String password) async {
    if (_client == null) return;
    
    try {
      await _client!.login(username: username, password: password);
      _client!.beginSyncConversations();
    } catch (e) {
      rethrow;
    }
  }

  void setCurrentTopic(String? topicId) {
    _currentTopicId = topicId;
    notifyListeners();
  }

  Future<void> loadMessages(String topicId) async {
    if (_client == null) return;
    
    try {
      final result = await _client!.syncChatLogs(topicId: topicId, limit: 50);
      final logs = result['logs'] as List<ChatLog>? ?? [];
      _messages[topicId] = logs;
      notifyListeners();
    } catch (e) {
      debugPrint('Load messages error: $e');
    }
  }

  Future<void> sendText(String topicId, String text) async {
    if (_client == null) return;
    
    try {
      await _client!.sendText(topicId: topicId, text: text);
    } catch (e) {
      debugPrint('Send text error: $e');
      rethrow;
    }
  }

  Future<void> deleteConversation(String topicId) async {
    if (_client == null) return;
    
    try {
      await _client!.removeConversation(topicId);
    } catch (e) {
      debugPrint('Delete conversation error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _client?.shutdown();
    super.dispose();
  }
}
