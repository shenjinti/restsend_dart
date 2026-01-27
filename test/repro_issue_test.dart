
import 'package:test/test.dart';
import 'package:restsend_dart/restsend_dart.dart';
import 'dart:async';

void main() {
  group('Reproduction of onConversationUpdated issue', () {
    test('Verify onConversationUpdated is called for regular chat messages', () async {
      final client = Client('https://chat.ruzhila.cn');
      
      const topicId = 'topic_1';
      const senderId = 'user_2';
      
      // Inject topic into store to avoid network call
      client.store.topics[topicId] = Topic()
        ..id = topicId
        ..cachedAt = DateTime.now();
      
      bool updatedCalled = false;
      client.onConversationUpdated = (conversation) {
        updatedCalled = true;
      };

      final req = ChatRequest()
        ..type = 'chat'
        ..topicId = topicId
        ..chatId = 'chat_1'
        ..seq = 10
        ..attendee = senderId
        ..content = (Content()
          ..type = 'text'
          ..text = 'Hello');

      // Call the handler
      final handler = client.handlers['chat'];
      expect(handler, isNotNull);
      
      await handler!(topicId, senderId, req);

      expect(updatedCalled, true, reason: 'onConversationUpdated should be called for new messages');
    });

    test('Verify onConversationUpdated for seq=0 messages', () async {
      final client = Client('https://chat.ruzhila.cn');
      
      const topicId = 'topic_1';
      const senderId = 'user_2';
      
      client.store.topics[topicId] = Topic()
        ..id = topicId
        ..cachedAt = DateTime.now();
      
      bool updatedCalled = false;
      client.onConversationUpdated = (conversation) {
        updatedCalled = true;
      };

      final req = ChatRequest()
        ..type = 'chat'
        ..topicId = topicId
        ..chatId = 'chat_1'
        ..seq = 0 // seq = 0
        ..attendee = senderId
        ..content = (Content()
          ..type = 'text'
          ..text = 'Hello');

      final handler = client.handlers['chat'];
      await handler!(topicId, senderId, req);

      expect(updatedCalled, true, reason: 'onConversationUpdated SHOULD now be called when seq is 0 if chatId is present');
    });

    test('Verify onConversationUpdated for already cached conversation with new message', () async {
      final client = Client('https://chat.ruzhila.cn');
      
      const topicId = 'topic_1';
      const senderId = 'user_2';
      
      final topic = Topic()
        ..id = topicId
        ..cachedAt = DateTime.now();
      client.store.topics[topicId] = topic;

      // Seed the conversation in store
      final initialConversation = Conversation.fromTopic(topic);
      initialConversation.lastSeq = 5;
      client.store.conversations[topicId] = initialConversation;
      
      bool updatedCalled = false;
      client.onConversationUpdated = (conversation) {
        updatedCalled = true;
        expect(conversation.lastSeq, 10);
      };

      final req = ChatRequest()
        ..type = 'chat'
        ..topicId = topicId
        ..chatId = 'chat_2'
        ..seq = 10 // new message with higher seq
        ..attendee = senderId
        ..content = (Content()
          ..type = 'text'
          ..text = 'Hello again');

      final handler = client.handlers['chat'];
      await handler!(topicId, senderId, req);

      expect(updatedCalled, true, reason: 'onConversationUpdated should be called for newer messages');
    });

    test('Verify onConversationUpdated maintains lastMessage for old messages', () async {
      final client = Client('https://chat.ruzhila.cn');
      
      const topicId = 'topic_1';
      const senderId = 'user_2';
      
      final topic = Topic()
        ..id = topicId
        ..lastSeq = 10
        ..cachedAt = DateTime.now();
      client.store.topics[topicId] = topic;

      // Seed the conversation in store with a last message
      final initialLastMessage = Content()..type = 'text'..text = 'Latest';
      final initialConversation = Conversation.fromTopic(topic)
        ..lastSeq = 10
        ..lastMessage = initialLastMessage
        ..lastMessageSeq = 10;
      client.store.updateConversation(initialConversation);
      
      bool updatedCalled = false;
      client.onConversationUpdated = (conversation) {
        updatedCalled = true;
        // The fix: conversation.lastMessage should stay 'Latest' because seq 5 < 10
        expect(conversation.lastMessage?.text, 'Latest');
      };

      // Receive an OLD message (seq = 5 < 10)
      final req = ChatRequest()
        ..type = 'chat'
        ..topicId = topicId
        ..chatId = 'chat_old'
        ..seq = 5
        ..attendee = senderId
        ..content = (Content()
          ..type = 'text'
          ..text = 'Old message');

      final handler = client.handlers['chat'];
      await handler!(topicId, senderId, req);

      expect(updatedCalled, true);
    });
  });
}
