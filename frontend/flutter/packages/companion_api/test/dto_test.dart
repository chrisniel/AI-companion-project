import 'package:companion_api/companion_api.dart';
import 'package:test/test.dart';

void main() {
  group('AuthVerifyResponse', () {
    test('deserializes from valid JSON', () {
      final json = {
        'authenticated': true,
        'token_type': 'Bearer',
        'message': 'Token verified',
      };
      final dto = AuthVerifyResponse.fromJson(json);
      expect(dto.authenticated, isTrue);
      expect(dto.tokenType, 'Bearer');
      expect(dto.message, 'Token verified');
      expect(dto.toJson(), json);
    });

    test('implements equality and defaults', () {
      const a = AuthVerifyResponse();
      const b = AuthVerifyResponse(
        authenticated: true,
        tokenType: 'Bearer',
        message: 'Token is valid and authenticated.',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('throws on malformed types', () {
      expect(
        () => AuthVerifyResponse.fromJson({'authenticated': 'not_a_bool'}),
        throwsFormatException,
      );
    });
  });

  group('SystemStatusResponse', () {
    test('deserializes and serializes valid JSON', () {
      final json = {
        'status': 'online',
        'platform': 'Windows 11',
        'python_version': '3.11.9',
        'hostname': 'HOST-PC',
        'cpu_count': 16,
        'version': '0.1.0',
        'database_connected': true,
        'timestamp': '2026-10-09T12:00:00Z',
      };
      final dto = SystemStatusResponse.fromJson(json);
      expect(dto.status, 'online');
      expect(dto.platform, 'Windows 11');
      expect(dto.cpuCount, 16);
      expect(dto.databaseConnected, isTrue);
      expect(dto.toJson(), json);
    });

    test('throws when required field is missing or invalid', () {
      expect(
        () => SystemStatusResponse.fromJson({'platform': 123}),
        throwsFormatException,
      );
    });
  });

  group('ModelStatusResponse', () {
    test('deserializes and serializes valid JSON', () {
      final json = {
        'provider': 'llama.cpp',
        'engine_version': 'b10936',
        'router_running': false,
        'managed_by_core': false,
        'runtime_state': 'MODEL_READY',
        'active_model': 'qwen2.5-7b',
        'model_resident': true,
        'model_loaded': true,
        'model_awake': true,
        'requested_profile': 'balanced',
        'requested_mmproj_offload': true,
        'generation_active': false,
        'mmproj_offload': true,
        'is_loaded': false,
        'active_profile': 'balanced',
        'context_size': 4096,
        'gpu_layers': 28,
        'idle_timeout_seconds': 900,
        'seconds_until_idle': 300,
        'seconds_until_unload': 600,
        'available_models': ['qwen2.5-7b', 'phi-3.5'],
      };
      final dto = ModelStatusResponse.fromJson(json);
      expect(dto.provider, 'llama.cpp');
      expect(dto.runtimeState, 'MODEL_READY');
      expect(dto.activeModel, 'qwen2.5-7b');
      expect(dto.modelResident, isTrue);
      expect(dto.modelLoaded, isTrue);
      expect(dto.modelAwake, isTrue);
      expect(dto.availableModels, contains('qwen2.5-7b'));
      expect(dto.toJson(), json);
    });
  });

  group('Conversation DTOs', () {
    test('ConversationCreate serializes correctly', () {
      const c = ConversationCreate(title: 'Chat 1', characterId: 'default');
      expect(c.toJson(), {'title': 'Chat 1', 'character_id': 'default'});
    });

    test('ConversationOut deserializes and serializes', () {
      final json = {
        'id': 'conv-123',
        'title': 'Test Chat',
        'character_id': 'default',
        'owner_id': 'owner-1',
        'created_at': '2026-10-09T10:00:00Z',
        'updated_at': '2026-10-09T10:05:00Z',
        'message_count': 5,
      };
      final dto = ConversationOut.fromJson(json);
      expect(dto.id, 'conv-123');
      expect(dto.title, 'Test Chat');
      expect(dto.messageCount, 5);
      expect(dto.toJson(), json);
    });

    test('ConversationListOut deserializes items and total', () {
      final json = {
        'items': [
          {
            'id': 'c1',
            'title': 'Chat 1',
            'character_id': 'default',
            'owner_id': 'owner-1',
            'created_at': '2026-10-09T10:00:00Z',
            'updated_at': '2026-10-09T10:00:00Z',
            'message_count': 2,
          }
        ],
        'total': 1,
      };
      final dto = ConversationListOut.fromJson(json);
      expect(dto.total, 1);
      expect(dto.items.length, 1);
      expect(dto.items.first.title, 'Chat 1');
    });
  });

  group('Message DTOs & Binding Correction A', () {
    test('MessageSend with null attachmentIds OMITS attachment_ids from JSON', () {
      const msg = MessageSend(
        userText: 'Hello AI',
        clientMessageId: 'client-uuid-1',
      );
      final json = msg.toJson();
      expect(json.containsKey('attachment_ids'), isFalse);
      expect(json['user_text'], 'Hello AI');
      expect(json['client_message_id'], 'client-uuid-1');
      expect(json['attachment_ids'], isNull); // Map does not contain key
    });

    test('MessageSend with empty list serializes empty list', () {
      const msg = MessageSend(
        userText: 'Hello AI',
        attachmentIds: [],
      );
      final json = msg.toJson();
      expect(json['attachment_ids'], equals([]));
    });

    test('MessageSend throws on empty userText', () {
      expect(
        () => MessageSend.fromJson({'user_text': ''}),
        throwsFormatException,
      );
    });

    test('AttachmentRef deserializes and serializes', () {
      final json = {
        'id': 'att-1',
        'filename_display': 'photo.png',
        'mime_type': 'image/png',
        'size_bytes': 1024,
      };
      final ref = AttachmentRef.fromJson(json);
      expect(ref.id, 'att-1');
      expect(ref.filenameDisplay, 'photo.png');
      expect(ref.sizeBytes, 1024);
      expect(ref.toJson(), json);
    });

    test('MessageOut deserializes and serializes full payload', () {
      final json = {
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'sender': 'assistant',
        'content': 'Hello there!',
        'status': 'completed',
        'sequence_no': 2,
        'client_message_id': 'client-1',
        'model_name': 'qwen2.5-7b',
        'prompt_tokens': 15,
        'completion_tokens': 5,
        'created_at': '2026-10-09T10:00:00Z',
        'attachments': <Map<String, dynamic>>[],
      };
      final dto = MessageOut.fromJson(json);
      expect(dto.id, 'msg-1');
      expect(dto.sender, 'assistant');
      expect(dto.content, 'Hello there!');
      expect(dto.status, 'completed');
      expect(dto.sequenceNo, 2);
      expect(dto.toJson(), json);
    });

    test('MessageListOut deserializes correctly', () {
      final json = {
        'items': [
          {
            'id': 'msg-1',
            'conversation_id': 'conv-1',
            'sender': 'user',
            'content': 'Hi',
            'status': 'completed',
            'sequence_no': 1,
            'created_at': '2026-10-09T10:00:00Z',
            'attachments': <Map<String, dynamic>>[],
          }
        ],
        'total': 1,
      };
      final list = MessageListOut.fromJson(json);
      expect(list.total, 1);
      expect(list.items.first.content, 'Hi');
    });
  });

  group('SSE Event DTOs', () {
    test('implements value equality', () {
      const t1 = SseTokenEvent('hello');
      const t2 = SseTokenEvent('hello');
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));

      const d1 = SseDoneEvent();
      const d2 = SseDoneEvent(finishReason: 'stop');
      expect(d1, equals(d2));

      const e1 = SseErrorEvent(code: 'ERR', message: 'fail');
      const e2 = SseErrorEvent(code: 'ERR', message: 'fail');
      expect(e1, equals(e2));
    });
  });
}
