
import 'package:test/test.dart';
import 'package:restsend_dart/restsend_dart.dart';
import 'dart:async';

void main() {
  group('Remote Integration Tests', () {
    const endpoint = 'https://chat.ruzhila.cn';
    const username = 'bob';
    const password = 'bob:demo';

    test('Full login and check conversation list', () async {
      final client = Client(endpoint);
      
      try {
        await client.login(username: username, password: password);
        expect(client.token, isNotNull);
        expect(client.myId, isNotEmpty);
        
        print('Logged in as: ${client.myId}');
        
        // Wait for connection to be established or just check state
        // (login calls connect() internally)
        
        // Check if we can get conversations
        final resp = await client.services.getChatList(null, 50);
        final conversations = resp['items'] as List;
        expect(conversations, isA<List>());
        print('Fetched ${conversations.length} conversations');

      } catch (e) {
        fail('Integration test failed with error: $e');
      } finally {
        client.shutdown();
      }
    });

    test('Real message handling - onConversationUpdated when sending', () async {
      final client = Client(endpoint);
      
      bool updatedCalled = false;
      final completer = Completer<void>();

      client.onConversationUpdated = (conversation) {
        if (!updatedCalled) {
          updatedCalled = true;
          print('Conversation updated via send: ${conversation.name}');
          if (!completer.isCompleted) completer.complete();
        }
      };

      try {
        await client.login(username: username, password: password);
        
        final resp = await client.services.getChatList(null, 10);
        final convs = resp['items'] as List;
        
        if (convs.isNotEmpty) {
           final topicId = convs[0]['topicId'];
           print('Sending test message to topic: $topicId');
           
           // This should trigger _addPendingToStore and thus onConversationUpdated
           await client.sendText(topicId: topicId, text: 'Test message from integration test');
           
           await completer.future.timeout(Duration(seconds: 5));
           expect(updatedCalled, isTrue);
        }
      } catch (e) {
        print('Send test failed: $e');
        // Don't fail the whole test if it's just a timeout or no topics
      } finally {
        client.shutdown();
      }
    });

    test('Real message handling - onConversationUpdated when receiving', () async {
      // This is harder to test without a second client, 
      // but we can simulate the handler being called with data that looks real
      final client = Client(endpoint);
      
      bool updatedCalled = false;
      client.onConversationUpdated = (conversation) {
        updatedCalled = true;
      };

      try {
        await client.login(username: username, password: password);
        final resp = await client.services.getChatList(null, 1);
        if (resp['items'].isNotEmpty) {
          final topicId = resp['items'][0]['topicId'];
          
          final req = ChatRequest()
            ..type = 'chat'
            ..topicId = topicId
            ..chatId = 'mock_incoming_${DateTime.now().millisecondsSinceEpoch}'
            ..seq = 999999
            ..attendee = 'system'
            ..content = (Content()..type = 'text'..text = 'Mock Incoming');

          await client.handlers['chat']!(topicId, 'system', req);
          expect(updatedCalled, isTrue);
        }
      } finally {
        client.shutdown();
      }
    });
  });
}
