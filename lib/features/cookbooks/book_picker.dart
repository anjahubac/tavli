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
  /// Izabrana knjiga ili null ako je korisnik odustao.
  Future<PickedBook?> pick();
}

class FileSelectorBookPicker implements BookPicker {
  const FileSelectorBookPicker();

  @override
  Future<PickedBook?> pick() async {
    const types = XTypeGroup(
      label: 'Kuvarske knjige',
      extensions: ['pdf', 'epub'],
      mimeTypes: ['application/pdf', 'application/epub+zip'],
      uniformTypeIdentifiers: ['com.adobe.pdf', 'org.idpf.epub-container'],
    );
    final file = await openFile(acceptedTypeGroups: [types]);
    if (file == null) return null;
    return PickedBook(name: file.name, bytes: await file.readAsBytes());
  }
}
