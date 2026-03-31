// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data'; // IMPORTANTE: Adicionamos esta biblioteca

Future<void> saveFile(String fileName, String content) async {
  final bom = utf8.encode('\uFEFF');
  final bytes = utf8.encode(content);
  final fullData = [...bom, ...bytes];

  // A MÁGICA ACONTECE AQUI: Converte a lista simples de números para Bytes Reais
  final uint8List = Uint8List.fromList(fullData);

  // Cria o Blob passando os bytes e avisando o navegador que é um arquivo CSV
  final blob = html.Blob([uint8List], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}
