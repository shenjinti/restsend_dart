import 'types.dart';

/// Callback functions for client events
class Callback {
  /// Connection successful
  void Function()? onConnected;

  /// Connecting
  void Function()? onConnecting;

  /// Connection broken
  void Function(String reason)? onNetBroken;

  /// Login failed
  void Function(String reason)? onAuthError;

  /// Kicked offline by another client
  void Function(String reason)? onKickoffByOtherClient;

  /// Message sending failed
  void Function(Topic topic, String chatId, int code)? onSendMessageFail;

  /// Received group application
  void Function(Topic topic, String message, String? source)? onTopicKnock;

  /// Group application rejected
  void Function(Topic topic, String userId, String message)?
      onTopicKnockReject;

  /// Group application approved
  void Function(Topic topic)? onTopicJoin;

  /// Received typing notification
  void Function(String topicId, String senderId)? onTyping;

  /// Received chat message
  OnMessageResponse? Function(Topic topic, ChatLog message)? onTopicMessage;

  /// Group announcement updated
  void Function(Topic topic, TopicNotice notice)? onTopicNoticeUpdated;

  /// Group member updated
  void Function(Topic topic, TopicMember member, bool isAdd)?
      onTopicMemberUpdated;

  /// Conversation updated
  void Function(Conversation conversation)? onConversationUpdated;

  /// Conversation removed
  void Function(String conversationId)? onConversationRemoved;

  /// Kicked out of the group
  void Function(Topic topic, String adminId, TopicMember user)? onTopicKickoff;

  /// Group dismissed
  void Function(Topic topic, User user)? onTopicDismissed;

  /// Group silenced
  void Function(Topic topic, String duration)? onTopicSilent;

  /// Group member silenced
  void Function(Topic topic, TopicMember member, String duration)?
      onTopicSilentMember;

  /// System message
  void Function(ChatRequest req)? onSystemMessage;

  Callback();
}
