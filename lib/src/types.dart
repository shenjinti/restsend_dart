import 'dart:convert';

Map<String, dynamic>? _safeMap(dynamic v) {
  if (v == null) return null;
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String) {
    try {
      final d = jsonDecode(v);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
  }
  return null;
}

String? _safeString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is Map || v is List) {
    try {
      return jsonEncode(v);
    } catch (_) {}
  }
  return v?.toString();
}


List<String>? _safeTags(dynamic v) {
  if (v == null) return null;
  if (v is List) {
    return v.map((e) {
      if (e is String) return e;
      if (e is Map) {
        // Try to extract label or name if available
        if (e.containsKey('label')) return e['label'].toString();
        if (e.containsKey('name')) return e['name'].toString();
        // Fallback to json string
        try {
          return jsonEncode(e);
        } catch (_) {}
      }
      return e.toString();
    }).toList();
  }
  return null;
}

/// Network connection states
enum NetworkState {
  connected('connected'),
  connecting('connecting'),
  disconnected('disconnected');

  const NetworkState(this.value);
  final String value;
}

/// Chat content types
class ChatContentType {
  static const String null_ = '';
  static const String text = 'text';
  static const String image = 'image';
  static const String video = 'video';
  static const String voice = 'voice';
  static const String file = 'file';
  static const String location = 'location';
  static const String sticker = 'sticker';
  static const String contact = 'contact';
  static const String invite = 'invite';
  static const String link = 'link';
  static const String logs = 'logs';
  static const String topicCreate = 'topic.create';
  static const String topicDismiss = 'topic.dismiss';
  static const String topicQuit = 'topic.quit';
  static const String topicKickout = 'topic.kickout';
  static const String topicJoin = 'topic.join';
  static const String topicNotice = 'topic.notice';
  static const String topicKnock = 'topic.knock';
  static const String topicKnockAccept = 'topic.knock.accept';
  static const String topicKnockReject = 'topic.knock.reject';
  static const String topicSilent = 'topic.silent';
  static const String topicSilentMember = 'topic.silent.member';
  static const String topicChangeOwner = 'topic.changeowner';
  static const String uploadFile = 'file.upload';
  static const String conversationUpdate = 'conversation.update';
  static const String conversationRemoved = 'conversation.removed';
  static const String updateExtra = 'update.extra';
}

/// Topic kinds
class TopicKind {
  static const String personal = 'personal';
  static const String group = 'group';
  static const String vip = 'vip';
  static const String system = 'system';
}

/// Chat request types
class ChatRequestType {
  static const String nop = 'nop';
  static const String chat = 'chat';
  static const String ping = 'ping';
  static const String typing = 'typing';
  static const String read = 'read';
  static const String response = 'resp';
  static const String kickout = 'kickout';
  static const String system = 'system';
}

/// Message status constants
const int logStatusSending = 0;
const int logStatusSent = 1;
const int logStatusReceived = 2;
const int logStatusRead = 3;
const int logStatusFailed = 4;

/// User model
class User {
  User(this.id);

  String id;
  String? name;
  String? avatar;
  String? publicKey;
  String? remark;
  bool isStar = false;
  String? locale;
  String? city;
  String? country;
  String? source;
  String? firstName;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? cachedAt;

  String get displayName {
    String name = this.name ?? firstName ?? id;
    if (remark != null && remark!.isNotEmpty) {
      name = '$remark($name)';
    }
    return name;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(json['id'] as String? ?? '')
      ..name = json['name'] as String?
      ..avatar = json['avatar'] as String?
      ..publicKey = json['publicKey'] as String?
      ..remark = json['remark'] as String?
      ..isStar = json['isStar'] as bool? ?? false
      ..locale = json['locale'] as String?
      ..city = json['city'] as String?
      ..country = json['country'] as String?
      ..source = json['source'] as String?
      ..firstName = json['firstName'] as String?
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null
      ..updatedAt = json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null
      ..cachedAt = json['cachedAt'] != null
          ? DateTime.parse(json['cachedAt'] as String)
          : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'publicKey': publicKey,
      'remark': remark,
      'isStar': isStar,
      'locale': locale,
      'city': city,
      'country': country,
      'source': source,
      'firstName': firstName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'cachedAt': cachedAt?.toIso8601String(),
    };
  }
}

/// Topic notice model
class TopicNotice {
  String? text;
  String? publisher;
  DateTime? updatedAt;

  TopicNotice({this.text, this.publisher, this.updatedAt});

  factory TopicNotice.fromJson(Map<String, dynamic> json) {
    return TopicNotice(
      text: json['text'] as String?,
      publisher: json['publisher'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'publisher': publisher,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Topic model
class Topic {
  String? id;
  String? name;
  String? icon;
  String? kind;
  String? remark;
  String? ownerId;
  String? attendeeId;
  List<String> admins = [];
  int members = 0;
  int lastSeq = 0;
  int lastReadSeq = 0;
  bool multiple = false;
  bool private = false;
  DateTime? createdAt;
  DateTime? updatedAt;
  TopicNotice? notice;
  bool muted = false;
  DateTime? cachedAt;

  Topic();

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic()
      ..id = json['id'] as String?
      ..name = json['name'] as String?
      ..icon = json['icon'] as String?
      ..kind = json['kind'] as String?
      ..remark = json['remark'] as String?
      ..ownerId = json['ownerId'] as String?
      ..attendeeId = json['attendeeId'] as String?
      ..admins = (json['admins'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          []
      ..members = json['members'] as int? ?? 0
      ..lastSeq = json['lastSeq'] as int? ?? 0
      ..lastReadSeq = json['lastReadSeq'] as int? ?? 0
      ..multiple = json['multiple'] as bool? ?? false
      ..private = json['private'] as bool? ?? false
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null
      ..updatedAt = json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null
      ..notice = json['notice'] != null
          ? TopicNotice.fromJson(json['notice'] as Map<String, dynamic>)
          : null
      ..muted = json['muted'] as bool? ?? false
      ..cachedAt = json['cachedAt'] != null
          ? DateTime.parse(json['cachedAt'] as String)
          : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'kind': kind,
      'remark': remark,
      'ownerId': ownerId,
      'attendeeId': attendeeId,
      'admins': admins,
      'members': members,
      'lastSeq': lastSeq,
      'lastReadSeq': lastReadSeq,
      'multiple': multiple,
      'private': private,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notice': notice?.toJson(),
      'muted': muted,
      'cachedAt': cachedAt?.toIso8601String(),
    };
  }
}

/// Topic member model
class TopicMember {
  String? topicId;
  String? userId;
  String? remark;
  DateTime? createdAt;
  DateTime? updatedAt;

  TopicMember();

  factory TopicMember.fromJson(Map<String, dynamic> json) {
    return TopicMember()
      ..topicId = json['topicId'] as String?
      ..userId = json['userId'] as String?
      ..remark = json['remark'] as String?
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null
      ..updatedAt = json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'topicId': topicId,
      'userId': userId,
      'remark': remark,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Message content model
class Content {
  String? type;
  bool encrypted = false;
  int checksum = 0;
  String? text;
  String? placeholder;
  String? thumbnail;
  String? duration;
  int size = 0;
  int width = 0;
  int height = 0;
  List<String> mentions = [];
  String? replyId;
  String? replyContent;
  Map<String, dynamic>? extra;
  bool unreadable = false;

  Content();

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content()
      ..type = json['type'] as String?
      ..encrypted = json['encrypted'] as bool? ?? false
      ..checksum = json['checksum'] as int? ?? 0
      ..text = _safeString(json['text'])
      ..placeholder = _safeString(json['placeholder'])
      ..thumbnail = _safeString(json['thumbnail'])
      ..duration = _safeString(json['duration'])
      ..size = json['size'] as int? ?? 0
      ..width = json['width'] as int? ?? 0
      ..height = json['height'] as int? ?? 0
      ..mentions = (json['mentions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          []
      ..replyId = json['replyId'] as String?
      ..replyContent = _safeString(json['replyContent'])
      ..extra = _safeMap(json['extra'])
      ..unreadable = json['unreadable'] as bool? ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'encrypted': encrypted,
      'checksum': checksum,
      'text': text,
      'placeholder': placeholder,
      'thumbnail': thumbnail,
      'duration': duration,
      'size': size,
      'width': width,
      'height': height,
      'mentions': mentions,
      'replyId': replyId,
      'replyContent': replyContent,
      'extra': extra,
      'unreadable': unreadable,
    };
  }
}

/// Chat log model
class ChatLog {
  int seq = 0;
  String? chatId;
  String? senderId;
  Content? content;
  DateTime? createdAt;
  DateTime? updatedAt;
  int status = 0;
  bool read = false;
  bool recall = false;
  bool isSentByMe = false;
  User? sender;

  ChatLog();

  bool get readable {
    if (content == null) return false;
    return content!.unreadable != true &&
        content!.type != '' &&
        content!.type != 'recall';
  }

  int compareSort(ChatLog other) {
    if (seq == other.seq) {
      final lhsDate = createdAt ?? DateTime.now();
      final rhsDate = other.createdAt ?? DateTime.now();
      return lhsDate.compareTo(rhsDate);
    }
    return seq - other.seq;
  }

  factory ChatLog.fromJson(Map<String, dynamic> json) {
    return ChatLog()
      ..seq = json['seq'] as int? ?? 0
      ..chatId = json['chatId'] as String? ?? json['id'] as String?
      ..senderId = json['senderId'] as String?
      ..content = json['content'] != null
          ? Content.fromJson(json['content'] as Map<String, dynamic>)
          : null
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null
      ..updatedAt = json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null
      ..status = json['status'] as int? ?? 0
      ..read = json['read'] as bool? ?? false
      ..recall = json['recall'] as bool? ?? false
      ..isSentByMe = json['isSentByMe'] as bool? ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'seq': seq,
      'chatId': chatId,
      'senderId': senderId,
      'content': content?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
      'read': read,
      'recall': recall,
      'isSentByMe': isSentByMe,
    };
  }
}

/// Conversation model
class Conversation {
  String? topicId;
  String? attendee;
  String? ownerId;
  bool multiple = false;
  String? kind;
  Topic? topic;
  String? name;
  String? remark;
  String? icon;
  bool sticky = false;
  int unread = 0;
  Content? lastMessage;
  DateTime? lastMessageAt;
  int lastMessageSeq = 0;
  String? lastSenderId;
  int lastReadSeq = 0;
  DateTime? lastReadAt;
  int lastSeq = 0;
  int startSeq = 0;
  DateTime? updatedAt;
  bool mute = false;
  int members = 0;
  List<String>? tags;
  Map<String, dynamic>? extra;
  Map<String, dynamic>? topicExtra;
  String? topicOwnerID;
  DateTime? cachedAt;
  User? lastMessageSender;

  Conversation();

  static Conversation fromTopic(Topic topic, [ChatLog? logItem]) {
    final conv = Conversation()
      ..topicId = topic.id
      ..attendee = topic.attendeeId
      ..ownerId = topic.ownerId
      ..multiple = topic.multiple
      ..kind = topic.kind
      ..name = topic.name
      ..remark = topic.remark
      ..icon = topic.icon
      ..mute = topic.muted
      ..members = topic.members
      ..lastSeq = topic.lastSeq
      ..lastReadSeq = topic.lastReadSeq
      ..updatedAt = topic.updatedAt
      ..cachedAt = topic.cachedAt;

    if (logItem != null && logItem.readable) {
      conv.lastSenderId = logItem.senderId;
      conv.lastMessage = logItem.content;
      conv.lastMessageAt = logItem.createdAt;
      conv.lastMessageSeq = logItem.seq;
      if (logItem.seq > conv.lastSeq) {
        conv.lastSeq = logItem.seq;
      }
    }

    return conv;
  }

  int compareSort(Conversation other) {
    final lhsDate = lastMessageAt ?? updatedAt ?? DateTime.now();
    final rhsDate = other.lastMessageAt ?? other.updatedAt ?? DateTime.now();
    return rhsDate.compareTo(lhsDate);
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation()
      ..topicId = json['topicId'] as String?
      ..attendee = json['attendee'] as String?
      ..ownerId = json['ownerId'] as String?
      ..multiple = json['multiple'] as bool? ?? false
      ..kind = json['kind'] as String?
      ..name = json['name'] as String?
      ..remark = _safeString(json['remark'])
      ..icon = json['icon'] as String?
      ..sticky = json['sticky'] as bool? ?? false
      ..unread = json['unread'] as int? ?? 0
      ..lastMessage = json['lastMessage'] != null
          ? Content.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null
      ..lastMessageAt = json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null
      ..lastMessageSeq = json['lastMessageSeq'] as int? ?? 0
      ..lastSenderId = _safeString(json['lastSenderId'])
      ..lastReadSeq = json['lastReadSeq'] as int? ?? 0
      ..lastReadAt = json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'] as String)
          : null
      ..lastSeq = json['lastSeq'] as int? ?? 0
      ..startSeq = json['startSeq'] as int? ?? 0
      ..updatedAt = json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null
      ..mute = json['mute'] as bool? ?? false
      ..members = json['members'] as int? ?? 0
      ..tags = _safeTags(json['tags'])
      ..extra = _safeMap(json['extra'])
      ..topicExtra = _safeMap(json['topicExtra'])
      ..topicOwnerID = json['topicOwnerID'] as String?
      ..cachedAt = json['cachedAt'] != null
          ? DateTime.parse(json['cachedAt'] as String)
          : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'topicId': topicId,
      'attendee': attendee,
      'ownerId': ownerId,
      'multiple': multiple,
      'kind': kind,
      'name': name,
      'remark': remark,
      'icon': icon,
      'sticky': sticky,
      'unread': unread,
      'lastMessage': lastMessage?.toJson(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessageSeq': lastMessageSeq,
      'lastSenderId': lastSenderId,
      'lastReadSeq': lastReadSeq,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastSeq': lastSeq,
      'startSeq': startSeq,
      'updatedAt': updatedAt?.toIso8601String(),
      'mute': mute,
      'members': members,
      'tags': tags,
      'extra': extra,
      'topicExtra': topicExtra,
      'topicOwnerID': topicOwnerID,
      'cachedAt': cachedAt?.toIso8601String(),
    };
  }
}

/// Chat request model
class ChatRequest {
  String? type;
  int code = 0;
  String? topicId;
  int seq = 0;
  String? attendee;
  Map<String, dynamic>? attendeeProfile;
  String? chatId;
  Content? content;
  String? e2eContent;
  String? message;
  DateTime? receivedAt;
  DateTime? createdAt;

  ChatRequest();

  factory ChatRequest.fromJson(Map<String, dynamic> json) {
    return ChatRequest()
      ..type = json['type'] as String?
      ..code = json['code'] as int? ?? 0
      ..topicId = json['topicId'] as String?
      ..seq = json['seq'] as int? ?? 0
      ..attendee = json['attendee'] as String?
      ..attendeeProfile = json['attendeeProfile'] as Map<String, dynamic>?
      ..chatId = json['chatId'] as String?
      ..content = json['content'] != null
          ? Content.fromJson(json['content'] as Map<String, dynamic>)
          : null
      ..e2eContent = json['e2eContent'] as String?
      ..message = json['message'] as String?
      ..receivedAt = json['receivedAt'] != null
          ? DateTime.parse(json['receivedAt'] as String)
          : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'code': code,
      'topicId': topicId,
      'seq': seq,
      'attendee': attendee,
      'attendeeProfile': attendeeProfile,
      'chatId': chatId,
      'content': content?.toJson(),
      'e2eContent': e2eContent,
      'message': message,
      'receivedAt': receivedAt?.toIso8601String(),
    };
  }
}

/// Message response model
class OnMessageResponse {
  bool hasRead = false;
  int code = 200;

  OnMessageResponse({this.hasRead = false, this.code = 200});
}

/// Conversation update fields
class ConversationUpdateFields {
  bool? sticky;
  bool? mute;
  List<String>? tags;
  Map<String, dynamic>? extra;
  String? remark;

  ConversationUpdateFields({
    this.sticky,
    this.mute,
    this.tags,
    this.extra,
    this.remark,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (sticky != null) map['sticky'] = sticky;
    if (mute != null) map['mute'] = mute;
    if (tags != null) map['tags'] = tags;
    if (extra != null) map['extra'] = extra;
    if (remark != null) map['remark'] = remark;
    return map;
  }
}

/// Upload result model
class UploadResult {
  bool external = false;
  String? path;
  String? fileName;
  String? ext;
  int size = 0;

  UploadResult();

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult()
      ..external = json['external'] as bool? ?? false
      ..path = json['path'] as String?
      ..fileName = json['fileName'] as String?
      ..ext = json['ext'] as String?
      ..size = json['size'] as int? ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'external': external,
      'path': path,
      'fileName': fileName,
      'ext': ext,
      'size': size,
    };
  }
}
