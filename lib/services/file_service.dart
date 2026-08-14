import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

class FileService {
  static Future<void> partagerExcel({
    required Uint8List bytes,
    required String nomFichier,
  }) async {
    final fichier = XFile.fromData(
      bytes,
      name: nomFichier,
      mimeType:
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [fichier],
        fileNameOverrides: [nomFichier],
        title: 'Planning Excel',
        downloadFallbackEnabled: true,
      ),
    );
  }
}