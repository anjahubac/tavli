import '../../data/cookbook_repository.dart';
import '../../domain/cookbook.dart';

const _noText =
    'Knjiga nema tekst (možda je skenirana). Podržani su PDF i EPUB sa tekstom.';
const _tooBig = 'Knjiga je prevelika (najviše 15 MB i 500 stranica).';

/// Poruka za grešku koju server vrati za knjigu (kod u `error_code`).
String? cookbookCodeText(String? code) => switch (code) {
  'no_text' => _noText,
  'too_large' || 'too_many_pages' => _tooBig,
  'corrupt' => 'Fajl je oštećen ili nije ispravna knjiga.',
  'unsupported_type' => 'Podržani su samo PDF i EPUB.',
  'duplicate' => 'Ova knjiga je već dodata u domaćinstvo.',
  'embed_invalid' ||
  'extract_failed' ||
  'failed' => 'Obrada knjige nije uspela. Pokušaj ponovo kasnije.',
  _ => null,
};

/// Poruka za prikaz kad rad sa knjigama ne uspe.
String cookbookFailureText(Object error) => switch (error) {
  CookbookOffline() =>
    'Nema veze sa internetom. Knjige i pitanja rade samo uz mrežu.',
  CookbookLimitReached() =>
    'Domaćinstvo već ima najviše 20 knjiga. Obriši neku pa pokušaj ponovo.',
  CookbookQuotaExceeded() =>
    'Limit je trenutno potrošen. Pokušaj malo kasnije.',
  CookbookRejected(:final code) =>
    cookbookCodeText(code) ?? 'Server ne prihvata ovu knjigu.',
  _ => 'Nešto nije u redu sa serverom. Pokušaj ponovo.',
};

/// Jedan red stanja ispod naslova knjige.
String cookbookStatusText(Cookbook book) => switch (book.status) {
  CookbookStatus.ready => 'Spremno, ${book.pages ?? '?'} stranica',
  CookbookStatus.processing =>
    book.pages == null
        ? 'Obrada…'
        : 'Obrada: ${book.nextPage - 1} od ${book.pages} stranica',
  CookbookStatus.uploaded => 'Čeka obradu',
  CookbookStatus.failed =>
    cookbookCodeText(book.errorCode) ?? 'Obrada nije uspela.',
};
