import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

Future<void> saveFile(String fileName, String content) async {
  Directory? directory;
  if (Platform.isAndroid) {
    directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  final file = File('${directory.path}/$fileName');

  // Salva com BOM e UTF-8
  final bom = utf8.encode('\uFEFF');
  final encodedData = utf8.encode(content);
  final fullData = [...bom, ...encodedData];

  await file.writeAsBytes(fullData, flush: true);
}
