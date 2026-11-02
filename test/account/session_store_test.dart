import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/session_store.dart';

import '../helpers/fake_secret_storage.dart';

void main() {
  test('čuva, čita i briše sesiju pod auth_session', () async {
    final storage = MapSecretStorage()
      ..values['api_keys'] = '[]'
      ..values['api_key_gemini'] = 'stari';
    final store = SessionStore(storage);

    expect(await store.read(), isNull);
    await store.write('{"fake":"session"}');
    expect(storage.values['auth_session'], '{"fake":"session"}');
    expect(await store.read(), '{"fake":"session"}');

    await store.clear();
    expect(await store.read(), isNull);
    // AI ključevi ostaju netaknuti.
    expect(storage.values, {'api_keys': '[]', 'api_key_gemini': 'stari'});
  });
}
