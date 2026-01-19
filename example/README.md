# Restsend Demo Application

A complete Flutter demo application showcasing the Restsend Dart SDK.

## Features

- 🔐 Guest and password login
- 💬 Real-time messaging
- 📋 Conversation list
- 💬 Chat interface
- 🔔 Unread message badges
- 🗑️ Delete conversations
- 📱 Material Design 3 UI

## Getting Started

### 1. Install Dependencies

```bash
cd example
flutter pub get
```

### 2. Run the App

```bash
flutter run
```

Or for web:

```bash
flutter run -d chrome
```

## Usage

### Login

1. Enter your server endpoint (e.g., `https://chat.ruzhila.cn`)
2. Choose login mode:
   - **Guest Mode**: Enter a guest ID (e.g., `guest_123`)
   - **Password Mode**: Enter username and password
3. Click "Login"

### Chat

1. View your conversations in the list
2. Tap on a conversation to open the chat
3. Type a message and press send
4. Long-press a conversation to delete it

## Screenshots

### Login Screen
- Guest and password login options
- Server endpoint configuration
- Material Design 3 UI

### Conversation List
- Shows all active conversations
- Unread message badges
- Last message preview
- Connection status indicator

### Chat Screen
- Real-time messaging
- Message bubbles
- Send status indicators
- Smooth scrolling

## Architecture

### Provider Pattern
Uses `provider` for state management to separate business logic from UI.

### Key Components

- **ChatProvider**: Manages SDK instance, conversations, and messages
- **LoginScreen**: Handles authentication
- **ConversationListScreen**: Displays conversation list
- **ChatScreen**: Chat interface

## SDK Features Demonstrated

- ✅ Guest login
- ✅ User login
- ✅ WebSocket connection management
- ✅ Real-time message sync
- ✅ Conversation management
- ✅ Message history loading
- ✅ Send text messages
- ✅ Delete conversations
- ✅ Connection status monitoring

## Customization

### Change Theme

Edit `main.dart`:

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.yourColor),
  useMaterial3: true,
)
```

### Add Features

The demo is easily extensible. You can add:
- Image/file sending
- Voice messages
- Group management
- User profiles
- And more!

## Troubleshooting

### Connection Issues

- Verify server endpoint is correct
- Check network connectivity
- Ensure server is running

### Build Issues

```bash
flutter clean
flutter pub get
flutter run
```

## Learn More

- [Restsend Dart SDK Documentation](../README.md)
- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Package](https://pub.dev/packages/provider)
