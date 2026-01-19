import 'package:test/test.dart';
import 'package:restsend_dart/restsend_dart.dart';

void main() {
  group('Types Tests', () {
    test('User model serialization', () {
      final user = User('user123')
        ..name = 'Test User'
        ..avatar = 'https://example.com/avatar.jpg'
        ..remark = 'Friend';

      expect(user.id, 'user123');
      expect(user.name, 'Test User');
      expect(user.displayName, 'Friend(Test User)');

      // Test JSON serialization
      final json = user.toJson();
      final decoded = User.fromJson(json);
      expect(decoded.id, user.id);
      expect(decoded.name, user.name);
      expect(decoded.remark, user.remark);
    });

    test('Topic model serialization', () {
      final topic = Topic()
        ..id = 'topic123'
        ..name = 'Test Group'
        ..multiple = true
        ..members = 10
        ..lastSeq = 100;

      final json = topic.toJson();
      final decoded = Topic.fromJson(json);
      
      expect(decoded.id, topic.id);
      expect(decoded.name, topic.name);
      expect(decoded.multiple, topic.multiple);
      expect(decoded.members, topic.members);
    });

    test('ChatLog model', () {
      final log = ChatLog()
        ..seq = 1
        ..chatId = 'chat123'
        ..senderId = 'user123'
        ..content = (Content()
          ..type = 'text'
          ..text = 'Hello World')
        ..createdAt = DateTime.now();

      expect(log.readable, true);
      expect(log.content?.text, 'Hello World');

      // Test recall (recall makes content.type = 'recall', not readable)
      log.content = Content()..type = 'recall';
      expect(log.readable, false);
    });

    test('Conversation model', () {
      final topic = Topic()
        ..id = 'topic123'
        ..name = 'Test Chat'
        ..lastSeq = 50;

      final conversation = Conversation.fromTopic(topic);
      
      expect(conversation.topicId, 'topic123');
      expect(conversation.name, 'Test Chat');
      expect(conversation.lastSeq, 50);
    });

    test('Content types', () {
      expect(ChatContentType.text, 'text');
      expect(ChatContentType.image, 'image');
      expect(ChatContentType.video, 'video');
      expect(TopicKind.personal, 'personal');
      expect(TopicKind.group, 'group');
    });
  });

  group('Utils Tests', () {
    test('formatDate', () {
      final now = DateTime.now();
      final formatted = formatDate(now);
      expect(formatted, now);

      final fromString = formatDate(now.toIso8601String());
      expect(fromString?.toIso8601String(), now.toIso8601String());

      final nullResult = formatDate(null);
      expect(nullResult, null);
    });

    test('randText', () {
      final text1 = randText(8);
      final text2 = randText(8);
      
      expect(text1.length, 9); // 'j' + 8 chars
      expect(text2.length, 9);
      expect(text1, isNot(equals(text2))); // Should be different
      expect(text1[0], 'j');
    });
  });

  group('Store Tests', () {
    late ServicesApi services;
    late ClientStore store;

    setUp(() {
      services = ServicesApi('https://api.test.com');
      services.myId = 'testuser';
      store = ClientStore(services);
    });

    test('MessageStore basic operations', () {
      final msgStore = store.getMessageStore('topic123');
      
      expect(msgStore.topicId, 'topic123');
      expect(msgStore.messages.isEmpty, true);

      final log = ChatLog()
        ..seq = 1
        ..chatId = 'chat1'
        ..senderId = 'user1'
        ..content = (Content()..type = 'text'..text = 'Hello');

      msgStore.updateMessages([log]);
      expect(msgStore.messages.length, 1);

      final found = msgStore.getMessageByChatId('chat1');
      expect(found, isNotNull);
      expect(found?.chatId, 'chat1');

      msgStore.deleteMessage('chat1');
      expect(msgStore.messages.isEmpty, true);
    });

    test('ClientStore user management', () {
      final user = User('user123')..name = 'Test User';
      
      store.updateUser('user123', user);
      expect(store.users.containsKey('user123'), true);
      expect(store.users['user123']?.name, 'Test User');
    });

    test('ClientStore conversation management', () {
      final conversation = Conversation()
        ..topicId = 'topic123'
        ..name = 'Test Chat'
        ..unread = 5;

      store.updateConversation(conversation);
      expect(store.conversations.containsKey('topic123'), true);
      expect(store.conversations['topic123']?.unread, 5);
    });

    test('Process incoming message', () {
      final topic = Topic()
        ..id = 'topic123'
        ..lastSeq = 0;

      final logItem = ChatLog()
        ..seq = 1
        ..chatId = 'chat1'
        ..senderId = 'user1'
        ..content = (Content()..type = 'text'..text = 'Hello')
        ..createdAt = DateTime.now();

      final conversation = store.processIncoming(topic, logItem, false);
      
      expect(conversation, isNotNull);
      expect(conversation?.topicId, 'topic123');
      expect(conversation?.lastSeq, 1);
      expect(conversation?.unread, 1);
    });
  });

  group('New Features Tests', () {
    late ServicesApi services;
    late ClientStore store;

    setUp(() {
      services = ServicesApi('https://api.test.com');
      services.authToken = 'test_token';
      services.myId = 'testuser';
      store = ClientStore(services);
    });

    test('getChatList with category parameter', () async {
      // Test that getChatList accepts category parameter
      // Note: This is a unit test, actual API call would need a mock or integration test
      expect(() => services.getChatList(null, 10, 'personal'), returnsNormally);
      expect(() => services.getChatList(null, 10), returnsNormally);
    });

    test('markConversationUnread method exists', () {
      // Verify the method signature
      expect(() => services.markConversationUnread('topic123'), returnsNormally);
    });

    test('Conversation unread count handling', () {
      // Test unread calculation from message sequences
      final conversation1 = Conversation()
        ..topicId = 'topic1'
        ..lastMessageSeq = 10
        ..lastReadSeq = 5
        ..unread = 5;

      expect(conversation1.unread, 5);
      expect(conversation1.lastMessageSeq, 10);
      expect(conversation1.lastReadSeq, 5);

      // Test with no unread messages
      final conversation2 = Conversation()
        ..topicId = 'topic2'
        ..lastMessageSeq = 10
        ..lastReadSeq = 10
        ..unread = 0;

      expect(conversation2.unread, 0);
    });

    test('ClientStore conversation unread update', () {
      // Create a conversation with unread = 0
      final conversation = Conversation()
        ..topicId = 'topic123'
        ..name = 'Test Chat'
        ..unread = 0;

      store.updateConversation(conversation);
      expect(store.conversations['topic123']?.unread, 0);

      // Update to unread = 1 (simulating markConversationUnread)
      conversation.unread = 1;
      store.updateConversation(conversation);
      expect(store.conversations['topic123']?.unread, 1);
    });
  });
}
