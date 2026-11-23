/// Kuvarska knjiga domaćinstva i odgovor nad knjigama (spec 026). Knjigu i
/// njene delove obrađuje server; aplikacija ih samo prikazuje.
library;

enum CookbookStatus { uploaded, processing, ready, failed }

class Cookbook {
  const Cookbook({
    required this.id,
    required this.title,
    required this.filename,
    required this.status,
    this.pages,
    this.nextPage = 1,
    this.errorCode,
  });

  final String id;
  final String title;
  final String filename;
  final CookbookStatus status;

  /// Broj stranica, poznat tek kad obrada izvuče tekst.
  final int? pages;

  /// Sledeća stranica za obradu; za prikaz napretka.
  final int nextPage;

  /// Kod greške servera kad je [status] failed (npr. `no_text`).
  final String? errorCode;

  /// Udeo obrađenih stranica (0 do 1), ili null dok se broj stranica ne zna.
  double? get progress {
    final total = pages;
    if (total == null || total < 1) return null;
    return ((nextPage - 1) / total).clamp(0.0, 1.0);
  }
}

/// Mesto u knjizi odakle odgovor dolazi.
class CookbookSource {
  const CookbookSource({
    required this.bookId,
    required this.title,
    required this.page,
    this.recipeId,
  });

  final String bookId;
  final String title;
  final int page;
  final String? recipeId;

  String get label =>
      recipeId == null ? '$title, str. $page' : 'Sačuvani recept: $title';

  @override
  bool operator ==(Object other) =>
      other is CookbookSource &&
      other.bookId == bookId &&
      other.title == title &&
      other.page == page &&
      other.recipeId == recipeId;

  @override
  int get hashCode => Object.hash(bookId, title, page, recipeId);
}

class CookbookAnswer {
  const CookbookAnswer({required this.content, this.sources = const []});

  /// „Ne znam": nema odgovora u knjigama, bez izmišljenog izvora.
  const CookbookAnswer.unknown() : content = 'ne znam', sources = const [];

  final String content;
  final List<CookbookSource> sources;

  bool get known => sources.isNotEmpty;
}
