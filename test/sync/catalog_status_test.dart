import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/sync/catalog_status.dart';
import 'package:tavli/sync/sync_remote.dart';

void main() {
  CatalogStatus of(String code) => catalogStatusFor(PermanentSyncError(code));

  test('server bez tabela kataloga je stariji server', () {
    for (final code in ['PGRST205', '42P01', '404']) {
      expect(of(code), CatalogStatus.notOnServer, reason: code);
    }
  });

  test('odbijen pristup nikad nije stariji server', () {
    for (final code in ['42501', '403']) {
      expect(of(code), CatalogStatus.accessDenied, reason: code);
      expect(of(code), isNot(CatalogStatus.notOnServer), reason: code);
    }
  });

  test('ostale trajne greške su neuspeh kataloga', () {
    for (final code in ['23514', '400', 'PGRST204']) {
      expect(of(code), CatalogStatus.failed, reason: code);
    }
  });
}
