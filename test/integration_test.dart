import 'package:test/test.dart';
import 'package:restsend_dart/restsend_dart.dart';

void main() {
  group('Connection Tests', () {
    test('Connection initialization', () {
      final conn = Connection('https://chat.ruzhila.cn');
      expect(conn.endpoint, 'wss://chat.ruzhila.cn');
      expect(conn.networkState, 'disconnected');
    });

    test('Message handlers setup', () {
      final conn = Connection('https://chat.ruzhila.cn');
      
      expect(conn.handlers.containsKey('nop'), true);
      expect(conn.handlers.containsKey('ping'), true);
      expect(conn.handlers.containsKey('resp'), true);
      expect(conn.handlers.containsKey('kickout'), true);
    });

    test('ChatRequest creation for text', () {
      final conn = Connection('https://chat.ruzhila.cn');
      
      // This would normally send, but we're just testing the structure
      expect(() {
        final req = ChatRequest()
          ..type = 'chat'
          ..topicId = 'topic123'
          ..chatId = 'chat123'
          ..content = (Content()
            ..type = 'text'
            ..text = 'Hello World');
        
        expect(req.type, 'chat');
        expect(req.topicId, 'topic123');
        expect(req.content?.text, 'Hello World');
      }, returnsNormally);
    });
  });

  group('Callback Tests', () {
    test('Callback setup', () {
      final callback = Callback();
      
      var connectedCalled = false;
      callback.onConnected = () {
        connectedCalled = true;
      };
      
      callback.onConnected?.call();
      expect(connectedCalled, true);
    });

    test('Message callback', () {
      final callback = Callback();
      
      Topic? receivedTopic;
      ChatLog? receivedMessage;
      
      callback.onTopicMessage = (topic, message) {
        receivedTopic = topic;
        receivedMessage = message;
        return OnMessageResponse(hasRead: true, code: 200);
      };

      final topic = Topic()..id = 'topic123';
      final message = ChatLog()
        ..chatId = 'chat123'
        ..content = (Content()..type = 'text'..text = 'Test');

      final response = callback.onTopicMessage?.call(topic, message);
      
      expect(receivedTopic?.id, 'topic123');
      expect(receivedMessage?.chatId, 'chat123');
      expect(response?.hasRead, true);
      expect(response?.code, 200);
    });
  });

  group('Client Tests', () {
    test('Client initialization', () {
      final client = Client('https://chat.ruzhila.cn');
      
      expect(client.endpoint, 'wss://chat.ruzhila.cn');
      expect(client.services, isNotNull);
      expect(client.store, isNotNull);
      expect(client.myId, isEmpty);
    });

    test('Client message handlers', () {
      final client = Client('https://chat.ruzhila.cn');
      
      expect(client.handlers.containsKey('typing'), true);
      expect(client.handlers.containsKey('chat'), true);
      expect(client.handlers.containsKey('read'), true);
    });

    test('Store integration', () {
      final client = Client('https://chat.ruzhila.cn');
      
      final msgStore = client.store.getMessageStore('topic123');
      expect(msgStore, isNotNull);
      expect(msgStore.topicId, 'topic123');
    });
  });

  group('Services API Tests', () {
    test('ServicesApi initialization', () {
      final services = ServicesApi('https://chat.ruzhila.cn');
      
      expect(services.endpoint, 'https://chat.ruzhila.cn');
      expect(services.myId, isNull);
      expect(services.authToken, isNull);
    });

    test('Backend API integration', () {
      final services = ServicesApi('https://chat.ruzhila.cn');
      services.authToken = 'test-token';
      
      final backend = services.backend;
      expect(backend, isNotNull);
      expect(backend.token, 'test-token');
    });
  });
}
