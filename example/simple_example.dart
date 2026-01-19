import 'package:restsend_dart/restsend_dart.dart';

/// Simple example demonstrating basic SDK usage
void main() async {
  print('=== Restsend Dart SDK Example ===\n');

  // Initialize logger
  initLogger();

  // Create client instance
  print('1. Creating client...');
  final client = Client('https://chat.ruzhila.cn');

  // Setup callbacks
  client.onConnected = () {
    print('✅ Connected to server');
  };

  client.onNetBroken = (reason) {
    print('❌ Connection broken: $reason');
  };

  client.onConversationUpdated = (conversation) {
    print('📋 Conversation updated: ${conversation.name}');
  };

  client.onTopicMessage = (topic, message) {
    print('💬 New message from ${message.senderId}: ${message.content?.text}');
    return OnMessageResponse(hasRead: true, code: 200);
  };

  try {
    // Login as guest
    print('\n2. Logging in as guest...');
    await client.guestLogin(guestId: 'demo_user_${DateTime.now().millisecondsSinceEpoch}');
    print('✅ Logged in successfully');
    print('   User ID: ${client.myId}');

    // Sync conversations
    print('\n3. Syncing conversations...');
    client.beginSyncConversations(10);
    await Future.delayed(const Duration(seconds: 2));

    // Example: Get user info
    print('\n4. Getting user info...');
    final user = await client.getUser(client.myId);
    if (user != null) {
      print('   User: ${user.displayName}');
    }

    print('\n✅ Example completed successfully!');
    print('\nTo try more features, check out the Flutter demo app in example/');

  } catch (e) {
    print('\n❌ Error: $e');
  } finally {
    // Cleanup
    print('\n5. Disconnecting...');
    client.shutdown();
    print('✅ Disconnected');
  }
}
