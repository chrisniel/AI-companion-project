import 'dart:async';
import 'dart:convert';
import 'package:companion_api/companion_api.dart';
import 'package:test/test.dart';

void main() {
  const parser = SseStreamParser();

  group('SseStreamParser', () {
    test('parses simple token and done events', () async {
      final input = [
        'data: {"type": "token", "content": "Hello"}\n\n',
        'data: {"type": "token", "content": " world"}\n\n',
        'data: {"type": "done", "finish_reason": "stop"}\n\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      expect(events.length, 3);
      expect(events[0], const SseTokenEvent('Hello'));
      expect(events[1], const SseTokenEvent(' world'));
      expect(events[2], const SseDoneEvent(finishReason: 'stop'));
    });

    test('dedupes terminal done followed by [DONE]', () async {
      final input = [
        'data: {"type": "token", "content": "Hi"}\n\n',
        'data: {"type": "done", "finish_reason": "stop"}\n\n',
        'data: [DONE]\n\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      // Exactly 1 token and 1 done event; [DONE] is deduped
      expect(events.length, 2);
      expect(events[0], const SseTokenEvent('Hi'));
      expect(events[1], const SseDoneEvent(finishReason: 'stop'));
    });

    test('handles standalone [DONE] when type:done is absent', () async {
      final input = [
        'data: {"type": "token", "content": "Standalone"}\n\n',
        'data: [DONE]\n\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      expect(events.length, 2);
      expect(events[0], const SseTokenEvent('Standalone'));
      expect(events[1], const SseDoneEvent(finishReason: 'stop'));
    });

    test('handles error event following partial tokens', () async {
      final input = [
        'data: {"type": "token", "content": "Partial token"}\n\n',
        'data: {"type": "error", "code": "MODEL_GENERATION_FAILED", "message": "OOM occurred"}\n\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      expect(events.length, 2);
      expect(events[0], const SseTokenEvent('Partial token'));
      expect(events[1], const SseErrorEvent(code: 'MODEL_GENERATION_FAILED', message: 'OOM occurred'));
    });

    test('emits UNEXPECTED_EOF when stream closes before terminal frame', () async {
      final input = [
        'data: {"type": "token", "content": "Partial token"}\n\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      expect(events.length, 2);
      expect(events[0], const SseTokenEvent('Partial token'));
      expect(events[1], isA<SseErrorEvent>());
      final err = events[1] as SseErrorEvent;
      expect(err.code, 'UNEXPECTED_EOF');
    });

    test('handles split CRLF across chunk boundaries', () async {
      final input = [
        'data: {"type": "token", "content": "A"}\r',
        '\n\r',
        '\ndata: {"type": "done"}\r\n\r\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      expect(events.length, 2);
      expect(events[0], const SseTokenEvent('A'));
      expect(events[1], const SseDoneEvent());
    });

    test('handles multiline data within single event', () async {
      final input = [
        'data: line1\n',
        'data: line2\n\n',
        'data: [DONE]\n\n',
      ];
      final stream = Stream.fromIterable(input);
      final events = await parser.parseTextStream(stream).toList();

      expect(events.length, 2);
      expect(events[0], const SseUnknownEvent('line1\nline2'));
      expect(events[1], const SseDoneEvent());
    });

    test('handles fragmented UTF-8 across raw byte chunks', () async {
      // 🚀 is 4 bytes: 0xF0, 0x9F, 0x9A, 0x80
      const fullText = 'data: {"type": "token", "content": "Rocket 🚀"}\n\n'
          'data: {"type": "done"}\n\n';
      final allBytes = utf8.encode(fullText);

      // Find where 🚀 starts in bytes
      final rocketIndex = fullText.indexOf('🚀');
      final byteIndex = utf8.encode(fullText.substring(0, rocketIndex)).length;

      // Split right in the middle of 🚀's 4 bytes
      final chunk1 = allBytes.sublist(0, byteIndex + 2);
      final chunk2 = allBytes.sublist(byteIndex + 2);

      final byteStream = Stream.fromIterable(<List<int>>[chunk1, chunk2]);
      final events = await parser.parseByteStream(byteStream).toList();

      expect(events.length, 2);
      expect(events[0], const SseTokenEvent('Rocket 🚀'));
      expect(events[1], const SseDoneEvent());
    });

    test('stream cancellation halts parser', () async {
      final controller = StreamController<String>();
      final events = <SseEvent>[];

      final sub = parser.parseTextStream(controller.stream).listen((event) {
        events.add(event);
      });

      controller.add('data: {"type": "token", "content": "1"}\n\n');
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1);

      await sub.cancel();
      controller.add('data: {"type": "token", "content": "2"}\n\n');
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1); // No new events received

      await controller.close();
    });
  });
}
