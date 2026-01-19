# Restsend Dart SDK

A powerful real-time messaging client library for Dart and Flutter.

## Features

- 🚀 Real-time messaging via WebSocket
- 💬 Chat conversations and messages
- 👥 User management
- 📦 Message storage and caching
- 🔄 Auto-reconnection
- 💪 Type-safe API
- ✅ Full test coverage

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  restsend_dart: ^1.0.0
```

## Quick Start

```dart
import 'package:restsend_dart/restsend_dart.dart';

void main() async {
  // Create client
  final client = Client('https://chat.ruzhila.cn');
  
  // Login
  await client.guestLogin(guestId: 'user123');
  
  // Listen to messages
  client.onTopicMessageCallback = (topic, message) {
    print('New message: ${message.content}');
  };
  
  // Send message
  await client.sendText(
    topicId: 'topic123',
    text: 'Hello, World!',
  );
}
```

## Documentation

See the [example](example/) directory for more usage examples.

## Testing

```bash
dart test
```

## License

MIT
