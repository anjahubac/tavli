import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Izabrana knjiga: ime fajla i sadržaj.
class PickedBook {
  const PickedBook({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Bira PDF ili EPUB sa uređaja.
abstract interface class BookPicker {
  /// Izabrane knjige, ili prazna lista ako je korisnik odustao.
  Future<List<PickedBook>> pick();
}

class FileSelectorBookPicker implements BookPicker {
  const FileSelectorBookPicker();

  @override
  Future<List<PickedBook>> pick() async {
    const types = XTypeGroup(
      label: 'Kuvarske knjige',
      extensions: ['pdf', 'epub'],
      mimeTypes: ['application/pdf', 'application/epub+zip'],
      uniformTypeIdentifiers: ['com.adobe.pdf', 'org.idpf.epub-container'],
    );
    final files = await openFiles(acceptedTypeGroups: [types]);
    return [
      for (final file in files)
        PickedBook(name: file.name, bytes: await file.readAsBytes()),
    ];
  }
}
