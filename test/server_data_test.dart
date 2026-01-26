import 'package:test/test.dart';
import 'package:restsend_dart/restsend_dart.dart';

void main() {
  group('Server Data Parsing Tests', () {
    test('Parse conversation with topicOwnerId (from real server)', () {
      // Real data from server (anonymized)
      final json = {
        'cid': 224130,
        'ownerId': 'user_owner',
        'updatedAt': '2026-01-20T11:49:29.485+08:00',
        'topicId': 'user_owner:wa_mock_wa_extuid003:wa001:wa:75008',
        'remark': 'mock_user_name',
        'lastReadSeq': 6,
        'lastReadAt': '2026-01-20T11:49:29.638+08:00',
        'unread': 0,
        'startSeq': 0,
        'extra': {'isReplay': 'Y'},
        'lastSenderId': 'user_owner',
        'lastMessage': {
          'type': 'sticker',
          'text': '{"msgSource":"SYSTEM","type":"Unsupported message type"}',
          'extra': {'isPush': 'Y'}
        },
        'lastMessageAt': '2026-01-20T11:49:29+08:00',
        'lastMessageSeq': 5,
        'name': 'mock_user_name',
        'icon': '/api/avatar/wa_mock_wa_extuid003',
        'multiple': true,
        'members': 2,
        'lastSeq': 6,
        'topicExtra': {
          'joinGroupTime': '2025-12-18 11:41:22',
          'lastAgentTime': '2025-12-18T11:44:42.35122461+08:00',
          'source': 'wa',
          'topicType': 'single',
          'wxId': 'mock_wxid'
        },
        'topicOwnerId': 'user_owner',
        'topicCreatedAt': '2025-12-18T11:41:22.827+08:00'
      };

      final conversation = Conversation.fromJson(json);

      expect(conversation.topicId, 'user_owner:wa_mock_wa_extuid003:wa001:wa:75008');
      expect(conversation.name, 'mock_user_name');
      expect(conversation.unread, 0);
      expect(conversation.lastSeq, 6);
      expect(conversation.lastMessageSeq, 5);
      expect(conversation.topicOwnerID, 'user_owner', reason: 'Should parse topicOwnerId field');
      expect(conversation.topicCreatedAt, isNotNull, reason: 'Should parse topicCreatedAt field');
      expect(conversation.topicExtra, isNotNull);
      expect(conversation.topicExtra!['source'], 'wa');
    });

    test('Parse conversation with sticky and tags (from real server)', () {
      final json = {
        'cid': 252114,
        'ownerId': 'user_owner',
        'updatedAt': '2026-01-15T14:29:02.598+08:00',
        'topicId': 'user_owner:wa_123456:a1532:wa:70778',
        'sticky': true,
        'remark': 'test_user',
        'lastReadSeq': 2,
        'lastReadAt': '2026-01-23T18:01:11.402+08:00',
        'unread': 0,
        'startSeq': 0,
        'tags': [
          {'id': 171, 'type': 2, 'label': 'No reply in 3 mins'}
        ],
        'extra': {'isReplay': 'N'},
        'lastSenderId': 'user_owner',
        'lastMessage': {
          'type': 'sticker',
          'text': '{"msgSource":"SYSTEM","type":"Pending reply reminder"}',
          'extra': {'isPush': 'Y'}
        },
        'lastMessageAt': '2026-01-15T14:03:29+08:00',
        'lastMessageSeq': 2,
        'name': 'test_user',
        'icon': 'http://example.com/avatar.jpg',
        'multiple': true,
        'members': 2,
        'lastSeq': 2,
        'topicExtra': {
          'aiAssistIsOpen': 'N',
          'chatTopInfo': 'Sensitive info detected',
          'completeStatus': 'N'
        },
        'topicOwnerId': 'user_owner',
        'topicCreatedAt': '2026-01-12T17:56:57+08:00'
      };

      final conversation = Conversation.fromJson(json);

      expect(conversation.sticky, true, reason: 'Should parse sticky field');
      expect(conversation.tags, isNotNull);
      expect(conversation.tags!.length, 1);
      expect(conversation.tags![0], 'No reply in 3 mins', reason: 'Should extract label from tag object');
      expect(conversation.topicOwnerID, 'user_owner');
      expect(conversation.topicCreatedAt, isNotNull);
      expect(conversation.extra!['isReplay'], 'N');
    });

    test('Parse conversation with high unread count', () {
      final json = {
        'cid': 223690,
        'ownerId': 'user_owner',
        'updatedAt': '2025-12-18T11:41:00.225+08:00',
        'topicId': 'user_sender:wa_mock_wa_extuid002:wa001:wa:5675',
        'remark': 'mock_user_name_2',
        'lastReadSeq': 0,
        'lastReadAt': null,
        'unread': 10,
        'startSeq': 0,
        'lastSenderId': 'user_owner',
        'lastMessage': {
          'type': 'sticker',
          'text': '{"msgSource":"SYSTEM","type":"Agent transfer, user_sender -> user_owner"}',
          'extra': {'isPush': 'Y'}
        },
        'lastMessageAt': '2025-12-08T19:08:51+08:00',
        'lastMessageSeq': 10,
        'name': 'mock_user_name_2',
        'icon': '/api/avatar/wa_mock_wa_extuid002',
        'multiple': true,
        'members': 2,
        'lastSeq': 10,
        'topicExtra': {
          'gptClose': 'Y',
          'isReferral': 'Y',
          'transferStatus': 1
        },
        'topicOwnerId': 'user_owner',
        'topicCreatedAt': '2025-11-25T20:50:54.585+08:00'
      };

      final conversation = Conversation.fromJson(json);

      expect(conversation.unread, 10);
      expect(conversation.lastReadSeq, 0);
      expect(conversation.lastReadAt, null);
      expect(conversation.topicOwnerID, 'user_owner');
      expect(conversation.topicCreatedAt, isNotNull);
    });
  });
}
