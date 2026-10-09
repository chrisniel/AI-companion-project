import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('UuidUtils.generateV4', () {
    test('generates valid RFC 4122 v4 UUID', () {
      final uuid = UuidUtils.generateV4();
      final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(regex.hasMatch(uuid), isTrue);
    });

    test('generates distinct IDs on subsequent calls', () {
      final id1 = UuidUtils.generateV4();
      final id2 = UuidUtils.generateV4();
      expect(id1, isNot(equals(id2)));
    });
  });
}
