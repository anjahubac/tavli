import 'sync_remote.dart';

/// Ishod preuzimanja kataloga namirnica (018, data-model.md „Rollout“).
enum CatalogStatus {
  /// Tabele postoje i pročitane su (i kad su prazne).
  available,

  /// Stariji server bez tabela kataloga: nije greška za korisnika; matcher
  /// ostaje na Unresolved, a pokušava se pri sledećem preuzimanju.
  notOnServer,

  /// Tabele postoje, ali pristup domaćinstvu je odbijen.
  accessDenied,

  /// Druga trajna greška: katalog se preskače, ostalo preuzimanje ide dalje.
  failed,
}

/// Postojeći [classifySyncError] i nepoznatu tabelu i 42501 vidi kao trajnu
/// grešku; za katalog se razlikuju. Odbijen pristup nikad nije „stariji
/// server“.
CatalogStatus catalogStatusFor(PermanentSyncError error) =>
    switch (error.code) {
      'PGRST205' || '42P01' || '404' => CatalogStatus.notOnServer,
      '42501' || '403' => CatalogStatus.accessDenied,
      _ => CatalogStatus.failed,
    };
