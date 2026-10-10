import 'package:companion_api/companion_api.dart';
import 'package:test/test.dart';

void main() {
  group('HealthResponse', () {
    test('deserializes from valid JSON', () {
      final json = {'status': 'ok'};
      final response = HealthResponse.fromJson(json);

      expect(response.status, equals('ok'));
      expect(response.toJson(), equals({'status': 'ok'}));
    });

    test('throws FormatException on malformed status', () {
      final json = {'status': 123};
      expect(() => HealthResponse.fromJson(json), throwsFormatException);
    });

    test('implements value equality', () {
      const resp1 = HealthResponse(status: 'ok');
      const resp2 = HealthResponse(status: 'ok');
      const resp3 = HealthResponse(status: 'error');

      expect(resp1, equals(resp2));
      expect(resp1.hashCode, equals(resp2.hashCode));
      expect(resp1, isNot(equals(resp3)));
    });
  });
}
