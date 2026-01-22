import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'callback.dart';
import 'types.dart';
import 'utils.dart';

const int chatIdLength = 8;
const int requestTimeout = 15; // seconds
const int keepaliveInterval = 30; // seconds
const int reconnectInterval = 5; // seconds

class _WaitingResponse {
  final ChatRequest req;
  final Completer<ChatRequest> completer;
  final void Function(ChatLog?)? onsent;
  final void Function(ChatRequest)? onack;
  final void Function(String, dynamic)? onfail;

  _WaitingResponse({
    required this.req,
    required this.completer,
    this.onsent,
    this.onack,
    this.onfail,
  });
}

/// Connection class for WebSocket management
class Connection extends Callback {
  final String endpoint;
  String device = 'dart';
  String? token;

  bool _running = false;
  WebSocketChannel? _ws;
  Timer? _keepalive;
  Timer? _reconnect;
  String _status = 'disconnected';
  final List<ChatRequest> _pending = [];
  final Map<String, _WaitingResponse> _waiting = {};
  final Map<String, Function> handlers = {};

  Connection(String? endpoint)
      : endpoint = (endpoint ?? '').replaceAll(RegExp(r'http'), 'ws') {
    _start();
    handlers['nop'] = _onNop;
    handlers['ping'] = _onPing;
    handlers['system'] = _onSystem;
    handlers['resp'] = _onResponse;
    handlers['kickout'] = _onKickout;
  }

  /// Get network state
  String get networkState => _status;

  /// Start connection
  void _start() {
    _running = true;
    _ws = null;
    _keepalive = null;
    _reconnect = null;
    _status = 'disconnected';
    _pending.clear();
    _waiting.clear();
  }

  /// Shutdown connection
  void shutdown() {
    _running = false;
    _ws?.sink.close();
    _ws = null;
    _keepalive?.cancel();
    _keepalive = null;
    _reconnect?.cancel();
    _reconnect = null;
  }

  /// Try to reconnect
  void tryReconnect() {
    if (_status == 'disconnected' && _running) {
      connect();
    }
  }

  /// Immediate connect if needed
  Future<void> immediateConnectIfNeed() async {
    await connect();
  }

  /// App active callback
  Future<void> appActive() async {
    await immediateConnectIfNeed();
  }

  /// App deactive callback
  void appDeactive() {}

  /// Connect to WebSocket
  Future<void> connect() async {
    if (_status == 'connected' || _status == 'connecting') {
      return;
    }

    _status = 'connecting';
    onConnecting?.call();

    _keepalive?.cancel();
    _keepalive = null;

    _reconnect ??= Timer.periodic(
      Duration(seconds: reconnectInterval),
      (_) => tryReconnect(),
    );

    final url = '$endpoint/api/connect?device=$device&token=${token ?? ''}';

    try {
      final wsUrl = Uri.parse(url);
      _ws = WebSocketChannel.connect(wsUrl);

      _ws!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onClose,
        cancelOnError: false,
      );

      _onOpen();
    } catch (e) {
      logger.severe('WebSocket connection error: $e');
      _status = 'disconnected';
      onNetBroken?.call('connection error');
    }
  }

  void _onOpen() {
    _status = 'connected';
    onConnected?.call();

    final pending = List<ChatRequest>.from(_pending);
    _pending.clear();

    if (pending.isNotEmpty) {
      logger.info('Flushing ${pending.length} pending requests');
      for (final req in pending) {
        _ws?.sink.add(jsonEncode(req.toJson()));
      }
    }

    _keepalive = Timer.periodic(
      Duration(seconds: keepaliveInterval),
      (_) {
        if (_status != 'connected') {
          _keepalive?.cancel();
          _keepalive = null;
          return;
        }
        final ping = ChatRequest()
          ..type = 'ping'
          ..content = (Content()..text = DateTime.now().toString());
        _ws?.sink.add(jsonEncode(ping.toJson()));
      },
    );
  }

  void _onClose() {
    _status = 'disconnected';
    logger.warning('WebSocket closed');
    onNetBroken?.call('closed');
  }

  void _onError(dynamic error) {
    _status = 'disconnected';
    logger.warning('WebSocket error: $error');
    onNetBroken?.call('error');
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;

    logger.fine('Incoming message: $message');

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final req = ChatRequest.fromJson(data)..receivedAt = DateTime.now();

      _handleRequest(req).then((code) {
        if (req.chatId != null && req.type != 'resp') {
          sendResponse(req.chatId!, code ?? 200);
        }
      });
    } catch (e) {
      logger.severe('Error handling message: $e');
    }
  }

  Future<int?> _handleRequest(ChatRequest req) async {
    final handler = handlers[req.type];
    if (handler != null) {
      return await handler(req.topicId, req.attendee, req);
    } else {
      logger.warning('Unknown message type: ${req.type}');
      return 501;
    }
  }

  Future<int?> _onNop(String? topicId, String? senderId, ChatRequest req) async {
    // Do nothing
    return null;
  }

  Future<int?> _onPing(String? topicId, String? senderId, ChatRequest req) async {
    await doSendRequest(ChatRequest()
      ..type = 'resp'
      ..chatId = req.chatId
      ..code = 200
      ..content = req.content);
    return null;
  }

  Future<int?> _onSystem(String? topicId, String? senderId, ChatRequest req) async {
    onSystemMessage?.call(req);
    return null;
  }

  Future<int?> _onResponse(String? topicId, String? senderId, ChatRequest resp) async {
    final w = _waiting[resp.chatId];
    if (w != null) {
      _waiting.remove(resp.chatId);
      if (resp.code != 200) {
        logger.warning('Response error: ${resp.code}');
        w.onfail?.call(resp.chatId!, resp);
      } else {
        w.onack?.call(resp);
      }
      w.completer.complete(resp);
    } else {
      logger.warning('No waiting for response: ${resp.chatId}');
    }
    return null;
  }

  Future<int?> _onKickout(String? topicId, String? senderId, ChatRequest req) async {
    onKickoffByOtherClient?.call(req.message ?? 'kicked out');
    shutdown();
    return null;
  }

  void sendResponse(String chatId, int code) {
    doSendRequest(ChatRequest()
      ..type = 'resp'
      ..chatId = chatId
      ..code = code);
  }

  Future<ChatRequest> doSendRequest(ChatRequest req, {bool retry = true}) async {
    if (!_running) {
      throw Exception('Connection is shutdown');
    }

    if (_status != 'connected') {
      if (retry) {
        logger.fine('Adding to pending: ${req.chatId}');
        _pending.add(req);
        await immediateConnectIfNeed();
      }
      return req;
    }

    logger.fine('Outgoing: ${req.type} ${req.chatId}');
    _ws?.sink.add(jsonEncode(req.toJson()));
    return req;
  }

  Future<ChatRequest> sendAndWaitResponse(
    ChatRequest req, {
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
    bool retry = true,
  }) async {
    final logItem = _addPendingToStore(req);

    final completer = Completer<ChatRequest>();
    _waiting[req.chatId!] = _WaitingResponse(
      req: req,
      completer: completer,
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );

    onsent?.call(logItem);

    try {
      await doSendRequest(req, retry: retry);
    } catch (e) {
      final w = _waiting[req.chatId];
      if (w != null) {
        w.onfail?.call(req.chatId!, e);
        _waiting.remove(req.chatId);
      }
      rethrow;
    }

    // Set timeout
    Future.delayed(Duration(seconds: requestTimeout), () {
      final w = _waiting[req.chatId];
      if (w != null) {
        w.onfail?.call(req.chatId!, Exception('timeout'));
        _waiting.remove(req.chatId);
        if (!w.completer.isCompleted) {
          w.completer.completeError(Exception('timeout'));
        }
      }
    });

    return completer.future;
  }

  // Placeholder for subclass implementation
  ChatLog? _addPendingToStore(ChatRequest req) {
    return null;
  }

  /// Send typing indicator
  Future<ChatRequest> doTyping(String topicId) async {
    return await doSendRequest(
      ChatRequest()
        ..topicId = topicId
        ..type = 'typing',
      retry: false,
    );
  }

  /// Mark message as read
  Future<ChatRequest> doRead({required String topicId, required int lastSeq}) async {
    return await doSendRequest(
      ChatRequest()
        ..topicId = topicId
        ..type = 'read'
        ..seq = lastSeq,
      retry: false,
    );
  }

  /// Recall a message
  Future<ChatRequest> doRecall({
    required String topicId,
    required String chatId,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..topicId = topicId
        ..chatId = randText(chatIdLength)
        ..content = (Content()
          ..type = 'recall'
          ..text = chatId),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send text message
  Future<ChatRequest> doSendText({
    required String topicId,
    required String text,
    String? type,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = type ?? ChatContentType.text
          ..text = text
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send image message
  Future<ChatRequest> doSendImage({
    required String topicId,
    required String urlOrData,
    int? size,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'image'
          ..text = urlOrData
          ..size = size ?? 0
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send voice message
  Future<ChatRequest> doSendVoice({
    required String topicId,
    required String urlOrData,
    required String duration,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'voice'
          ..text = urlOrData
          ..duration = duration
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send video message
  Future<ChatRequest> doSendVideo({
    required String topicId,
    required String urlOrData,
    String? thumbnail,
    required String duration,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'video'
          ..text = urlOrData
          ..thumbnail = thumbnail
          ..duration = duration
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send file message
  Future<ChatRequest> doSendFile({
    required String topicId,
    required String urlOrData,
    required String filename,
    required int size,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'file'
          ..text = urlOrData
          ..placeholder = filename
          ..size = size
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send location message
  Future<ChatRequest> doSendLocation({
    required String topicId,
    required double latitude,
    required double longitude,
    required String address,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'location'
          ..text = '$latitude,$longitude'
          ..placeholder = address
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send link message
  Future<ChatRequest> doSendLink({
    required String topicId,
    required String url,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'link'
          ..text = url
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Send custom message
  Future<ChatRequest> doSendMessage({
    required String type,
    required String topicId,
    required String text,
    String? placeholder,
    List<String>? mentions,
    String? reply,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = type
          ..text = text
          ..placeholder = placeholder
          ..mentions = mentions ?? []
          ..replyId = reply),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }

  /// Update message extra data
  Future<ChatRequest> doUpdateExtra({
    required String topicId,
    required String chatId,
    Map<String, dynamic>? extra,
    void Function(ChatLog?)? onsent,
    void Function(ChatRequest)? onack,
    void Function(String, dynamic)? onfail,
  }) async {
    return await sendAndWaitResponse(
      ChatRequest()
        ..type = 'chat'
        ..chatId = randText(chatIdLength)
        ..topicId = topicId
        ..content = (Content()
          ..type = 'update.extra'
          ..text = chatId
          ..extra = extra),
      onsent: onsent,
      onack: onack,
      onfail: onfail,
    );
  }
}
