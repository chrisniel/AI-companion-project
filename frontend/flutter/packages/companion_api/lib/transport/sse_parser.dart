import 'dart:async';
import 'dart:convert';

import '../dto/sse_event_dto.dart';

/// Parses raw byte streams into typed [SseEvent] stream frames.
///
/// Implements SSE wire rules conforming to Local AI Runtime §18/§19:
/// - Robust against multi-byte UTF-8 chunks split across buffers.
/// - Handles split CRLF, LF, and CR line endings across packet boundaries.
/// - Concatenates multi-line `data:` fields within the same event frame.
/// - Emits [SseTokenEvent], [SseDoneEvent], [SseErrorEvent], and [SseUnknownEvent].
/// - Dedupes terminal outcomes (e.g. `type: done` followed by `[DONE]`).
/// - Emits fail-closed [SseErrorEvent] on unexpected EOF before terminal completion.
class SseStreamParser {
  const SseStreamParser();

  /// Converts a raw HTTP byte stream into a stream of typed [SseEvent] objects.
  Stream<SseEvent> parseByteStream(Stream<List<int>> byteStream) {
    // utf8.decoder retains partial multibyte bytes across chunks
    final textStream = byteStream.cast<List<int>>().transform(utf8.decoder);
    return parseTextStream(textStream);
  }

  /// Converts an SSE text chunk stream into a stream of typed [SseEvent] objects.
  Stream<SseEvent> parseTextStream(Stream<String> textStream) {
    late StreamController<SseEvent> controller;
    StreamSubscription<String>? subscription;

    String lineBuffer = '';
    final List<String> currentDataLines = [];
    bool terminalEmitted = false;

    void dispatchEvent() {
      if (currentDataLines.isEmpty) return;

      final rawData = currentDataLines.join('\n');
      currentDataLines.clear();

      if (terminalEmitted) {
        // Once terminal event has been emitted, ignore subsequent frames (e.g. [DONE] after done)
        return;
      }

      if (rawData == '[DONE]') {
        terminalEmitted = true;
        controller.add(const SseDoneEvent(finishReason: 'stop'));
        return;
      }

      try {
        final dynamic decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          final type = decoded['type'];
          if (type == 'token') {
            Object? content = decoded['content'];
            if (content == null && decoded['choices'] is List) {
              final choices = decoded['choices'] as List;
              if (choices.isNotEmpty && choices[0] is Map) {
                final delta = (choices[0] as Map)['delta'];
                if (delta is Map) {
                  content = delta['content'];
                }
              }
            }
            controller.add(SseTokenEvent((content ?? '').toString()));
            return;
          } else if (type == 'done') {
            terminalEmitted = true;
            final finishReason = decoded['finish_reason']?.toString() ?? 'stop';
            controller.add(SseDoneEvent(finishReason: finishReason));
            return;
          } else if (type == 'error') {
            terminalEmitted = true;
            final code = decoded['code']?.toString() ?? 'UNKNOWN_ERROR';
            final message = decoded['message']?.toString() ?? 'Streaming error encountered';
            controller.add(SseErrorEvent(code: code, message: message));
            return;
          }
        }
      } catch (_) {
        // Non-JSON payload or custom payload
      }

      controller.add(SseUnknownEvent(rawData));
    }

    void processLine(String line) {
      if (line.isEmpty) {
        // Empty line indicates event boundary
        dispatchEvent();
        return;
      }

      if (line.startsWith(':')) {
        // SSE Comment
        return;
      }

      if (line.startsWith('data:')) {
        var value = line.substring(5);
        if (value.startsWith(' ')) {
          value = value.substring(1);
        }
        currentDataLines.add(value);
      }
    }

    void onChunk(String chunk) {
      lineBuffer += chunk;

      int index = 0;
      while (index < lineBuffer.length) {
        final char = lineBuffer[index];
        if (char == '\r') {
          if (index + 1 < lineBuffer.length && lineBuffer[index + 1] == '\n') {
            // CRLF
            final line = lineBuffer.substring(0, index);
            lineBuffer = lineBuffer.substring(index + 2);
            index = 0;
            processLine(line);
          } else if (index + 1 == lineBuffer.length) {
            // Incomplete \r at end of chunk: wait for possible \n
            break;
          } else {
            // Single CR
            final line = lineBuffer.substring(0, index);
            lineBuffer = lineBuffer.substring(index + 1);
            index = 0;
            processLine(line);
          }
        } else if (char == '\n') {
          // LF
          final line = lineBuffer.substring(0, index);
          lineBuffer = lineBuffer.substring(index + 1);
          index = 0;
          processLine(line);
        } else {
          index++;
        }
      }
    }

    void onDone() {
      if (lineBuffer.isNotEmpty) {
        processLine(lineBuffer);
        lineBuffer = '';
      }
      if (currentDataLines.isNotEmpty) {
        dispatchEvent();
      }

      // Check for unexpected EOF before terminal completion
      if (!terminalEmitted) {
        controller.add(const SseErrorEvent(
          code: 'UNEXPECTED_EOF',
          message: 'Stream terminated unexpectedly before done or error frame.',
        ));
      }

      controller.close();
    }

    void onError(Object error, StackTrace stackTrace) {
      if (!terminalEmitted) {
        controller.add(SseErrorEvent(
          code: 'STREAM_ERROR',
          message: error.toString(),
        ));
      }
      controller.close();
    }

    controller = StreamController<SseEvent>(
      onListen: () {
        subscription = textStream.listen(
          onChunk,
          onError: onError,
          onDone: onDone,
          cancelOnError: false,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
