import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/backend_address.dart';

void main() {
  const fallback = 'http://127.0.0.1:8000';

  String choose({String? discovered, bool isWeb = false, bool custom = false}) =>
      chooseBackendUrl(discovered: discovered, isWeb: isWeb, customDefine: custom, fallback: fallback);

  test('a phone uses the address the service published', () {
    expect(choose(discovered: 'http://192.168.1.50:8000'), 'http://192.168.1.50:8000');
  });

  test('until the address is known, or if it is empty, the built-in one is used', () {
    expect(choose(), fallback);
    expect(choose(discovered: ''), fallback);
    expect(choose(discovered: '  '), fallback);
  });

  test('the web version stays on the built-in address (same PC)', () {
    expect(choose(discovered: 'http://192.168.1.50:8000', isWeb: true), fallback);
  });

  test('an address given at build time always wins', () {
    expect(choose(discovered: 'http://192.168.1.50:8000', custom: true), fallback);
  });
}
