# Quick Start Examples

## Simple Console Example

```dart
import 'package:restsend_dart/restsend_dart.dart';

void main() async {
  // Create client
  final client = Client('https://chat.ruzhila.cn');
  
  // Setup callbacks
  client.onTopicMessage = (topic, message) {
    print('New message: ${message.content?.text}');
    return OnMessageResponse(hasRead: true);
  };
  
  // Login
  await client.guestLogin(guestId: 'user123');
  
  // Send message
  await client.sendText(
    topicId: 'topic123',
    text: 'Hello, World!',
  );
}
```

Run: `dart run example/simple_example.dart`

## Flutter App Example

See the complete Flutter demo in [example/](./README.md)

### Key Features

1. **Login Screen**
   - Guest and password authentication
   - Server endpoint configuration

2. **Conversation List**
   - Real-time conversation updates
   - Unread message badges
   - Pull to refresh

3. **Chat Screen**
   - Real-time messaging
   - Message history
   - Send/receive status

### Run Flutter Demo

```bash
cd example
flutter pub get
flutter run
```

## More Examples

### Send Different Message Types

```dart
// Text message
await client.sendText(
  topicId: topicId,
  text: 'Hello!',
);

// Image message
await client.sendImage(
  topicId: topicId,
  urlOrData: 'https://example.com/image.jpg',
  size: 1024,
);

// File message
await client.sendFile(
  topicId: topicId,
  urlOrData: 'https://example.com/file.pdf',
  filename: 'document.pdf',
  size: 2048,
);
```

### Conversation Management

```dart
// Get conversations
client.beginSyncConversations();

// Delete conversation
await client.removeConversation(topicId);

// Mark as read
await client.setConversationRead(conversation);
```

### Message History

```dart
// Load chat history
final result = await client.syncChatLogs(
  topicId: topicId,
  lastSeq: conversation.lastSeq,
  limit: 50,
);

final messages = result['logs'] as List<ChatLog>;
```

## API Documentation

For complete API documentation, see [README.md](../README.md)
