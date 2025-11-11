// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'dart:async'; // Importação do Timer

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

import 'splash_screen.dart';

import 'package:share_plus/share_plus.dart';

import 'package:url_launcher/url_launcher.dart';

// Definido uma ÚNICA vez no topo do arquivo (Correção do Erro de Duplicação)
typedef PhraseSelectedCallback = void Function(String phrase);

void main() {
  runApp(const MyApp());
}

// ===================================================================
// DADOS GLOBAIS (Gerenciados pelo Provider) - AGORA PERSISTENTES
// ===================================================================

class AppData extends ChangeNotifier {
  static const String _kFileName = 'avaliacoes_registros.csv';

  // NOVIDADE: Lista para armazenar CADA avaliação como um registro de mapa
  List<Map<String, dynamic>> allEvaluationRecords = [];

  // Mapeamentos para cálculo em tempo real (retornados na Estatística)
  Map<int, Map<int, int>> shiftRatingsCount = {
    1: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    2: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  };
  Map<int, Map<String, int>> shiftDetailedRatings = {1: {}, 2: {}};

  // ✅ CORREÇÃO: Variável de Sentimento definida no topo (acessível por todos os métodos)
  final Map<String, bool> _sentimentMap = const {
    'Bem Temperada': true,
    'Comida quente': true,
    'Boa Variedade': true,
    'Sem Sal/Insossa': false,
    'Comida Fria': false,
    'Aparência Estranha': false,
    'Funcionários Atenciosos': true,
    'Reposição Rápida': true,
    'Organização Eficiente': true,
    'Atendimento Lento': false,
    'Demora na Limpeza': false,
    'Filas Grandes': false,
    'Ambiente Limpo': true,
    'Climatização Boa': true,
    'Ambiente Silencioso': true,
    'Ambiente Sujo': false,
    'Climatização Ruim': false,
    'Ambiente Barulhento': false,
  };

  final List<Color> pieColors = [
    Colors.red.shade700,
    Colors.deepOrange,
    Colors.amber,
    Colors.lightGreen,
    Colors.green.shade700,
  ];

  // Construtor: Chama o método de carregamento ao inicializar
  AppData() {
    Future.microtask(() => loadDataFromCSV());
  }

  // ===============================================================
  // MÉTODOS DE AVALIAÇÃO E LEITURA
  // ===============================================================

  // NOVO MÉTODO: Adiciona um NOVO registro de avaliação
  void addEvaluationRecord({
    required int star,
    required int shift,
    required Set<String> positiveFeedbacks,
    required Set<String> negativeFeedbacks,
    String? comment,
  }) {
    final newRecord = {
      'timestamp': DateTime.now().toIso8601String(),
      'turno': shift,
      'estrelas': star,
      'positivos': positiveFeedbacks.join('; '),
      'negativos': negativeFeedbacks.join('; '),
      'comentario': comment ?? '',
    };

    allEvaluationRecords.add(newRecord);

    _recalculateCounts();

    notifyListeners();
    saveDataToCSV();
  }

  // ✅ CORRIGIDO: Método para classificar o feedback (usado no _sendRating)
  bool isPositive(String phrase) {
    return _sentimentMap[phrase] ?? false;
  }

  void _recalculateCounts() {
    // Zera os contadores
    shiftRatingsCount = {1: {}, 2: {}};
    shiftDetailedRatings = {1: {}, 2: {}};

    for (var record in allEvaluationRecords) {
      final shift = record['turno'] as int;
      final star = record['estrelas'] as int;
      final positives = (record['positivos'] as String)
          .split('; ')
          .where((s) => s.isNotEmpty);
      final negatives = (record['negativos'] as String)
          .split('; ')
          .where((s) => s.isNotEmpty);

      // 1. Contagem de Estrelas
      shiftRatingsCount[shift]![star] =
          (shiftRatingsCount[shift]![star] ?? 0) + 1;

      // 2. Contagem Detalhada
      for (var phrase in positives) {
        shiftDetailedRatings[shift]![phrase] =
            (shiftDetailedRatings[shift]![phrase] ?? 0) + 1;
      }
      for (var phrase in negatives) {
        shiftDetailedRatings[shift]![phrase] =
            (shiftDetailedRatings[shift]![phrase] ?? 0) + 1;
      }
    }
  }

  // ===============================================================
  // MÉTODOS CSV SAVE/LOAD (Permanecem inalterados na lógica de CSV)
  // ===============================================================

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/avaliacoes_registros.csv';
  }

  Future<void> saveDataToCSV() async {
    final filePath = await _getFilePath();
    final file = File(filePath);

    List<List<dynamic>> csvData = [];

    // Cabeçalho
    csvData.add([
      'timestamp',
      'turno',
      'estrelas',
      'positivos_clicados',
      'negativos_clicados',
      'comentario',
    ]);

    // Linhas de dados (Itera sobre a lista de registros)
    for (var record in allEvaluationRecords) {
      csvData.add([
        record['timestamp'],
        record['turno'],
        record['estrelas'],
        record['positivos'],
        record['negativos'],
        record['comentario'],
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    await file.writeAsString(csvString);
  }

  Future<void> loadDataFromCSV() async {
    final filePath = await _getFilePath();
    final file = File(filePath);

    if (!(await file.exists())) return;

    final csvString = await file.readAsString();
    final csvData = const CsvToListConverter().convert(csvString);

    allEvaluationRecords.clear();

    // Pula o cabeçalho (linha 0)
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.length < 6) continue;

      allEvaluationRecords.add({
        'timestamp': row[0].toString(),
        'turno': row[1] as int,
        'estrelas': row[2] as int,
        'positivos': row[3].toString(),
        'negativos': row[4].toString(),
        'comentario': row[5].toString(),
      });
    }

    _recalculateCounts();
    notifyListeners();
  }

  // ===============================================================
  // MÉTODOS DE LEITURA (Getters)
  // ===============================================================

  Map<int, int> getStarRatings(int shift) =>
      shiftRatingsCount[shift] ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  Map<String, int> getDetailedRatings(int shift) =>
      shiftDetailedRatings[shift] ?? {};
  int getTotalStarRatings(int shift) =>
      getStarRatings(shift).values.fold(0, (sum, count) => sum + count);

  // ===============================================================
  // MÉTODOS PARA FILTRAR POR DIA ATUAL
  // ===============================================================

  // Método para obter apenas as avaliações do dia atual
  List<Map<String, dynamic>> getTodayEvaluationRecords(int shift) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allEvaluationRecords.where((record) {
      final recordDate = DateTime.parse(record['timestamp']);
      final recordDay = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
      );
      return recordDay == today && record['turno'] == shift;
    }).toList();
  }

  // Método para calcular contagens apenas do dia atual
  Map<int, int> getTodayStarRatings(int shift) {
    final todayRecords = getTodayEvaluationRecords(shift);
    final Map<int, int> todayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var record in todayRecords) {
      final star = record['estrelas'] as int;
      todayCounts[star] = (todayCounts[star] ?? 0) + 1;
    }

    return todayCounts;
  }

  // Método para calcular feedbacks detalhados apenas do dia atual
  Map<String, int> getTodayDetailedRatings(int shift) {
    final todayRecords = getTodayEvaluationRecords(shift);
    final Map<String, int> todayDetailed = {};

    for (var record in todayRecords) {
      final positives = (record['positivos'] as String)
          .split('; ')
          .where((s) => s.isNotEmpty);
      final negatives = (record['negativos'] as String)
          .split('; ')
          .where((s) => s.isNotEmpty);

      for (var phrase in positives) {
        todayDetailed[phrase] = (todayDetailed[phrase] ?? 0) + 1;
      }
      for (var phrase in negatives) {
        todayDetailed[phrase] = (todayDetailed[phrase] ?? 0) + 1;
      }
    }

    return todayDetailed;
  }

  // Método para obter total de avaliações do dia atual
  int getTodayTotalStarRatings(int shift) {
    final todayRecords = getTodayEvaluationRecords(shift);
    return todayRecords.length;
  }

  // ===============================================================
  // MÉTODOS PARA ÚLTIMOS 7 DIAS
  // ===============================================================

  // Método para obter avaliações dos últimos 7 dias (ontem + 6 dias anteriores)
  List<Map<String, dynamic>> getLast7DaysEvaluationRecords(int shift) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final sevenDaysAgo = yesterday.subtract(
      const Duration(days: 6),
    ); // ontem - 6 dias = 7 dias no total

    return allEvaluationRecords.where((record) {
      final recordDate = DateTime.parse(record['timestamp']);
      final recordDay = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
      );

      // ✅ MUDE: Inclui de sevenDaysAgo até yesterday (exclui hoje)
      return (recordDay.isAfter(
                sevenDaysAgo.subtract(const Duration(days: 1)),
              ) &&
              recordDay.isBefore(yesterday.add(const Duration(days: 1)))) &&
          record['turno'] == shift;
    }).toList();
  }

  // Método para obter contagem de estrelas por dia dos últimos 7 dias
  Map<DateTime, Map<int, int>> getLast7DaysStarRatings(int shift) {
    final last7DaysRecords = getLast7DaysEvaluationRecords(shift);
    final Map<DateTime, Map<int, int>> dailyCounts = {};

    for (var record in last7DaysRecords) {
      final recordDate = DateTime.parse(record['timestamp']);
      final recordDay = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
      );
      final star = record['estrelas'] as int;

      if (!dailyCounts.containsKey(recordDay)) {
        dailyCounts[recordDay] = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      }

      dailyCounts[recordDay]![star] = (dailyCounts[recordDay]![star] ?? 0) + 1;
    }

    // ✅ CORREÇÃO: Preencher dias faltantes de ONTEM até 7 dias atrás
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    for (int i = 0; i < 7; i++) {
      final day = yesterday.subtract(Duration(days: i));
      if (!dailyCounts.containsKey(day)) {
        dailyCounts[day] = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      }
    }

    return dailyCounts;
  }

  // Método para calcular a média das avaliações por dia
  Map<DateTime, double> getLast7DaysAverageRatings(int shift) {
    final dailyData = getLast7DaysStarRatings(shift);
    final Map<DateTime, double> averages = {};

    for (var entry in dailyData.entries) {
      final day = entry.key;
      final dayData = entry.value;

      int totalRatings = 0;
      int sum = 0;

      for (int star = 1; star <= 5; star++) {
        final count = dayData[star] ?? 0;
        totalRatings += count;
        sum += star * count;
      }

      averages[day] = totalRatings > 0 ? sum / totalRatings : 0.0;
    }

    return averages;
  }

  // Método para obter a categoria mais avaliada por dia
  Map<DateTime, Map<String, dynamic>> getLast7DaysMostRated(int shift) {
    final dailyData = getLast7DaysStarRatings(shift);
    final Map<DateTime, Map<String, dynamic>> mostRated = {};

    for (var entry in dailyData.entries) {
      final day = entry.key;
      final dayData = entry.value;

      int maxCount = 0;
      int mostRatedStar = 0;

      for (int star = 1; star <= 5; star++) {
        final count = dayData[star] ?? 0;
        if (count > maxCount) {
          maxCount = count;
          mostRatedStar = star;
        }
      }

      mostRated[day] = {'star': mostRatedStar, 'count': maxCount};
    }

    return mostRated;
  }

  // ✅ MÉTODO PARA CONVERTER NÚMERO PARA NOME DA CATEGORIA
  String getCategoryName(int stars) {
    switch (stars) {
      case 1:
        return 'Péssimo';
      case 2:
        return 'Ruim';
      case 3:
        return 'Neutro';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return '$stars estrelas';
    }
  }

  /// ✅ DIALOG DE SUCESSO COM OPÇÕES (CORRIGIDO)
  Future<void> _showExportSuccessDialog(
    BuildContext context,
    String filePath,
  ) async {
    // ✅ GARANTE QUE O CONTEXTO AINDA ESTÁ VÁLIDO
    if (!context.mounted) return;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: true, // ✅ PERMITE FECHAR CLICANDO FORA
      builder: (context) => AlertDialog(
        title: const Text('Exportação Concluída!'),
        content: const Text(
          'O arquivo CSV foi salvo com sucesso. O que deseja fazer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('Abrir Arquivo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(2),
            child: const Text('Compartilhar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(3),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    switch (result) {
      case 1: // Abrir Arquivo
        await Share.shareXFiles([XFile(filePath)]);
        break;
      case 2: // Compartilhar
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Exportação de Avaliações - Costa Foods');
        break;
      // case 3: OK - não faz nada
    }
  }

  // ✅ MÉTODO ALTERNATivo - Salvar Diretamente na Pasta Downloads
  Future<void> exportToDownloads(BuildContext context) async {
    try {
      final csvData = await _generateCSVContent();

      // Tentar encontrar a pasta Downloads
      String downloadsPath = await _getDownloadsPath();

      final file = File('$downloadsPath/avaliacoes_costa_foods.csv');
      await file.writeAsString(csvData, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arquivo salvo em: $downloadsPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Fallback: usar o método com escolha de diretório
      if (context.mounted) {
        await exportCSV(context);
      }
    }
  }

  String? _lastSavedPath; // ✅ Guardar o último caminho salvo

  // ✅ MÉTODO PARA SALVAR EM PASTA VISÍVEL (CORRIGIDO)
  Future<void> exportCSV(BuildContext context) async {
    try {
      final csvData = await _generateCSVContent();

      // ✅ USA Navigator.push para garantir que o pop-up seja gerenciado corretamente
      await showDialog<int>(
        context: context,
        barrierDismissible: true, // ✅ PERMITE FECHAR CLICANDO FORA
        builder: (context) => AlertDialog(
          title: const Text('Exportar Dados'),
          content: const Text('Escolha como deseja exportar o arquivo CSV:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(1); // ✅ FECHA O DIALOG
                _saveToDownloads(context, csvData);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Salvar no dispositivo'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(2); // ✅ FECHA O DIALOG
                _shareFile(context, csvData);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Compartilhar'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(0), // ✅ FECHA O DIALOG
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ SALVAR DIRETO NO DISPOSITIVO
  String? _lastSavedFilePath; // ✅ Guarda o último caminho salvo

  // ✅ SALVAR NO DISPOSITIVO - MÉTODO CORRIGIDO
  Future<void> _saveToDevice(BuildContext context, String csvData) async {
    try {
      // Usar diretório de documentos (funciona sem permissões especiais)
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'avaliacoes_costa_foods.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvData, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arquivo salvo com sucesso!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print('✅ Arquivo salvo em: ${file.path}'); // Para debug
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ DIALOG DE SUCESSO COM BOTÃO "ABRIR PASTA"
  void _showSaveSuccessDialog(
    BuildContext context,
    String filePath,
    String fileName,
  ) {
    final directoryPath = File(filePath).parent.path;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Arquivo Salvo!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Arquivo: $fileName'),
            const SizedBox(height: 8),
            Text(
              'Pasta: ${_getShortPath(directoryPath)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Text(
              'O arquivo CSV foi salvo com sucesso. Deseja abrir a pasta onde ele está?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openFileManager(directoryPath);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 111, 136, 63),
              foregroundColor: Colors.white,
            ),
            child: const Text('Abrir Pasta'),
          ),
        ],
      ),
    );
  }

  // ✅ ABRIR GERENCIADOR DE ARQUIVOS
  Future<void> _openFileManager(String path) async {
    try {
      if (Platform.isAndroid) {
        // Para Android, tenta abrir o gerenciador de arquivos
        final uri =
            'content://com.android.externalstorage.documents/document/primary:${_getAndroidStoragePath(path)}';

        if (await canLaunchUrl(Uri.parse(uri))) {
          await launchUrl(Uri.parse(uri));
        } else {
          // Fallback: tentar abrir com intent genérico
          await _openFileManagerFallback(path);
        }
      } else {
        await _openFileManagerFallback(path);
      }
    } catch (e) {
      print('Erro ao abrir gerenciador: $e');
      await _openFileManagerFallback(path);
    }
  }

  // ✅ FALLBACK PARA ABRIR GERENCIADOR
  Future<void> _openFileManagerFallback(String path) async {
    try {
      // Tenta abrir o diretório usando file://
      final uri = 'file://$path';

      if (await canLaunchUrl(Uri.parse(uri))) {
        await launchUrl(Uri.parse(uri));
      } else {
        // Mostra o caminho completo para o usuário
        _showPathDialog(path);
      }
    } catch (e) {
      _showPathDialog(path);
    }
  }

  // ✅ MOSTRAR CAMINHO COMPLETO
  void _showPathDialog(String path) {
    // Pode ser implementado se quiser mostrar um dialog com o caminho
    print('Caminho do arquivo: $path');
  }

  // ✅ CONVERTER CAMINHO PARA FORMATO ANDROID
  String _getAndroidStoragePath(String path) {
    // Converte caminho como /storage/emulated/0/Android/data/...
    // para formato que o gerenciador entenda
    if (path.contains('Android/data')) {
      final parts = path.split('Android/data/');
      if (parts.length > 1) {
        return 'Android%2Fdata%2F${parts[1]}';
      }
    }
    return Uri.encodeComponent(path);
  }

  // ✅ ENCURTAR CAMINHO PARA EXIBIÇÃO
  String _getShortPath(String path) {
    if (path.length > 50) {
      return '...${path.substring(path.length - 47)}';
    }
    return path;
  }

  // ✅ OBTER PASTA DOWNLOADS PÚBLICA (Android 10+)
  Future<String> _getPublicDownloadsPath() async {
    try {
      if (Platform.isAndroid) {
        // Método para Android - tenta acessar a pasta Downloads pública
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Navega para a pasta Downloads pública
          // Em muitos dispositivos fica em /storage/emulated/0/Download
          final downloadsPath =
              '${directory.parent.parent?.path ?? directory.path}/Download';
          final downloadsDir = Directory(downloadsPath);

          // Se não existir, tenta criar
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          return downloadsPath;
        }
      }

      // Fallback: usar Environment.DIRECTORY_DOWNLOADS
      final directory = await getDownloadsDirectory();
      if (directory != null) {
        return directory.path;
      }

      throw Exception('Não foi possível acessar a pasta Downloads');
    } catch (e) {
      // Fallback final: pasta de documentos
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir.path;
    }
  }

  Future<void> openLastSavedFile(BuildContext context) async {
    if (_lastSavedPath == null) {
      _showError(context, 'Nenhum arquivo salvo anteriormente');
      return;
    }

    try {
      final file = File(_lastSavedPath!);
      if (await file.exists()) {
        await _openFile(context, _lastSavedPath!);
      } else {
        _showError(context, 'Arquivo anterior não encontrado');
        _lastSavedPath = null;
      }
    } catch (e) {
      _showError(context, 'Erro ao abrir arquivo anterior');
    }
  }

  // ✅ SALVAR NO DISPOSITIVO
  Future<void> _saveToDownloads(BuildContext context, String csvData) async {
    try {
      // Tentar acessar o storage externo (Downloads)
      final directory = await getExternalStorageDirectory();

      if (directory == null) {
        throw Exception('Não foi possível acessar o armazenamento');
      }

      // Criar pasta Downloads se não existir
      final downloadsDir = Directory('${directory.path}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Nome do arquivo com timestamp
      final timestamp = DateTime.now().toString().replaceAll(
        RegExp(r'[^0-9]'),
        '_',
      );
      final fileName = 'avaliacoes_costa_foods_$timestamp.csv';
      final file = File('${downloadsDir.path}/$fileName');

      await file.writeAsString(csvData, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Arquivo salvo na pasta Downloads!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () =>
                  _shareFile(context, csvData), // Abrir via compartilhamento
            ),
          ),
        );
      }

      print('✅ Arquivo salvo em: ${file.path}');
    } catch (e) {
      // Fallback: salvar em documentos e compartilhar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível salvar nos Downloads. Compartilhando arquivo...',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        await _shareFile(context, csvData);
      }
    }
  }

  // ✅ SALVAR NA PASTA DE DOCUMENTOS (fallback)
  Future<void> _saveToDocuments(BuildContext context, String csvData) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final fileName = 'avaliacoes_costa_foods_${_getFormattedDate()}.csv';
      final file = File('${documentsDir.path}/$fileName');

      await file.writeAsString(csvData, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📁 Salvo em Documentos: $fileName'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Erro ao salvar em Documentos: $e');
      rethrow;
    }
  }

  // ✅ DATA FORMATADA PARA O NOME DO ARQUIVO
  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  // ✅ ABRIR ARQUIVO - MÉTODO FUNCIONAL
  Future<void> _openFile(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        // Compartilhar o arquivo para abrir com apps disponíveis
        await Share.shareXFiles([XFile(filePath)]);
      } else {
        _showError(context, 'Arquivo não encontrado');
      }
    } catch (e) {
      _showError(context, 'Não foi possível abrir o arquivo');
    }
  }

  // ✅ COMPARTILHAR ARQUIVO (mantém igual)
  Future<void> _shareFile(BuildContext context, String csvData) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/avaliacoes_costa_foods.csv');
      await file.writeAsString(csvData, flush: true);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Exportação de Avaliações - Costa Foods');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ OBTER PASTA DOWNLOADS
  Future<String> _getDownloadsPath() async {
    try {
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Tenta encontrar a pasta Downloads
          final downloadsDir = Directory('${directory.path}/Download');
          if (await downloadsDir.exists()) {
            return downloadsDir.path;
          }
          // Ou cria se não existir
          await downloadsDir.create(recursive: true);
          return downloadsDir.path;
        }
      }

      // Fallback: diretório de documentos
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir.path;
    } catch (e) {
      // Fallback final: diretório temporário
      final tempDir = await getTemporaryDirectory();
      return tempDir.path;
    }
  }

  // ✅ ABRIR PASTA - MÉTODO FUNCIONAL
  Future<void> _openFolder(BuildContext context, String filePath) async {
    try {
      final directory = File(filePath).parent;

      // Mostrar informações da pasta
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Local do Arquivo'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Arquivo salvo em:'),
                  const SizedBox(height: 8),
                  Text(
                    directory.path,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Para acessar:', style: TextStyle(fontSize: 12)),
                  const Text(
                    '• Abra o app "Arquivos" do seu dispositivo',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '• Navegue até a pasta mostrada acima',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () => _openFile(context, filePath),
                child: const Text('Abrir Arquivo'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError(context, 'Não foi possível abrir a pasta');
    }
  }

  // ✅ GERAR CONTEÚDO CSV (mantém igual)
  Future<String> _generateCSVContent() async {
    final List<List<dynamic>> csvData = [];

    csvData.add([
      'Data/Hora',
      'Turno',
      'Avaliação',
      'Categoria',
      'Feedbacks Positivos',
      'Feedbacks Negativos',
      'Comentário',
    ]);

    for (var record in allEvaluationRecords) {
      final category = getCategoryName(record['estrelas'] as int);
      final turno = record['turno'] == 1 ? 'Manhã/Tarde' : 'Noite/Madrugada';

      csvData.add([
        record['timestamp'],
        turno,
        '${record['estrelas']} estrelas ($category)',
        category,
        record['positivos'],
        record['negativos'],
        record['comentario'] ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  String _getFriendlyPath(String path) {
    // Simplificar o caminho para exibição
    if (path.contains('/data/data/')) {
      return 'Armazenamento Interno/App Documents';
    } else if (path.contains('/storage/emulated/')) {
      return 'Armazenamento Interno/Download';
    }
    return path;
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ✅ DIALOG DE SUCESSO COM AÇÕES FUNCIONAIS
  Future<void> _showSuccessDialog(
    BuildContext context,
    String filePath,
    String fileName,
  ) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivo Salvo!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arquivo salvo com sucesso:'),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Local: ${_getFriendlyPath(filePath)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_browser, size: 18),
                SizedBox(width: 4),
                Text('Abrir Arquivo'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(2),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open, size: 18),
                SizedBox(width: 4),
                Text('Abrir Pasta'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == 1) {
      await _openFile(context, filePath);
    } else if (result == 2) {
      await _openFolder(context, filePath);
    }
  }
}

// ===================================================================
// WIDGET PRINCIPAL E CONTROLADOR DE ABAS
// ===================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppData(),
      child: MaterialApp(
        title: 'Sistema de Avaliação',
        theme: ThemeData(
          primarySwatch: Colors.red,
          useMaterial3: true, // ✅ Design mais moderno e adaptável
        ),
        home: const AppTabsController(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // ✅ Força escala de texto responsiva
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: MediaQuery.of(
                context,
              ).textScaleFactor.clamp(0.8, 1.2),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

class AppTabsController extends StatefulWidget {
  const AppTabsController({super.key});

  @override
  State<AppTabsController> createState() => _AppTabsControllerState();
}

class _AppTabsControllerState extends State<AppTabsController> {
  int _selectedIndex = 0;
  int _currentShift = 1; // Estado do turno atual (1 ou 2)

  int? _selectedRatingFromHome;
  int? _initialTabIndex;

  // ✅ SENHA PARA ACESSAR ESTATÍSTICAS
  final String _statisticsPassword = "1234"; // Senha definida no código
  bool _showPasswordDialog = false;
  String _enteredPassword = "";

  // ✅ Timer para voltar à tela inicial após inatividade
  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(seconds: 20);

  // ✅ TIMER ESPECÍFICO PARA O TECLADO NUMÉRICO
  Timer? _keyboardInactivityTimer;
  final Duration _keyboardInactivityDuration = const Duration(seconds: 20);

  // 1. Lógica para determinar o turno padrão baseado no horário atual
  int _calculateDefaultShift() {
    final hour = DateTime.now().hour;
    // Turno 2: 18:00 (6 PM) até 05:59
    if (hour >= 18 || hour < 6) {
      return 2;
    } else {
      // Turno 1: 06:00 (6 AM) até 17:59
      return 1;
    }
  }

  @override
  void initState() {
    super.initState();
    // Inicializa o turno com o valor padrão
    _currentShift = _calculateDefaultShift();
    _startInactivityTimer(); // ✅ INICIA O TIMER
  }

  @override
  void dispose() {
    _keyboardInactivityTimer?.cancel(); // ✅ CANCELA TIMER DO TECLADO
    super.dispose();
  }

  // ✅ INICIA O TIMER DE INATIVIDADE
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (_selectedIndex != 0 && mounted) {
        _resetToHomeScreen(); // Volta para a tela inicial
      }
    });
  }

  // ✅ VOLTA PARA TELA INICIAL
  void _resetToHomeScreen() {
    // ✅ FECHA TODOS OS POP-UPS E SNACKBARS ANTES DE MUDAR DE TELA
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _selectedIndex = 0;
      _currentShift = _calculateDefaultShift();
      _selectedRatingFromHome = null;
      _initialTabIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voltando para tela inicial por inatividade'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ REINICIA O TIMER A CADA INTERAÇÃO
  void _resetTimerOnInteraction() {
    _startInactivityTimer();
  }

  // ✅ MOSTRA O DIALOG DE SENHA
  void _showPasswordInput() {
    setState(() {
      _showPasswordDialog = true;
      _enteredPassword = "";
    });
    _startKeyboardInactivityTimer(); // ✅ INICIA TIMER DO TECLADO
  }

  // ✅ INICIA O TIMER DE INATIVIDADE DO TECLADO
  void _startKeyboardInactivityTimer() {
    _keyboardInactivityTimer?.cancel();
    _keyboardInactivityTimer = Timer(_keyboardInactivityDuration, () {
      if (_showPasswordDialog && mounted) {
        _closeKeyboardDueToInactivity();
      }
    });
  }

  // ✅ FECHA O TECLADO POR INATIVIDADE
  void _closeKeyboardDueToInactivity() {
    setState(() {
      _showPasswordDialog = false;
      _enteredPassword = "";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teclado fechado por inatividade'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ REINICIA O TIMER DO TECLADO A CADA INTERAÇÃO
  void _resetKeyboardTimer() {
    _startKeyboardInactivityTimer();
  }

  // ✅ VERIFICA A SENHA
  void _checkPassword() {
    _keyboardInactivityTimer?.cancel(); // ✅ CANCELA TIMER DO TECLADO
    if (_enteredPassword == _statisticsPassword) {
      // Senha correta - permite acesso às estatísticas
      setState(() {
        _showPasswordDialog = false;
        _enteredPassword = "";
        _selectedIndex = 2; // Navega para estatísticas
      });
    } else {
      // Senha incorreta - mostra erro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha incorreta! Tente novamente.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _enteredPassword = ""; // Limpa o campo
      });
    }
  }

  // ✅ CANCELA O DIGITAR DA SENHA
  void _cancelPassword() {
    _keyboardInactivityTimer?.cancel(); // ✅ CANCELA TIMER DO TECLADO
    setState(() {
      _showPasswordDialog = false;
      _enteredPassword = "";
    });
  }

  // ✅ ADICIONA DÍGITO À SENHA
  void _addDigit(String digit) {
    _resetKeyboardTimer(); // ✅ REINICIA TIMER DO TECLADO
    if (_enteredPassword.length < 4) {
      setState(() {
        _enteredPassword += digit;
      });

      // Verifica automaticamente quando completar 4 dígitos
      if (_enteredPassword.length == 4) {
        _checkPassword();
      }
    }
  }

  // ✅ REMOVE O ÚLTIMO DÍGITO
  void _removeDigit() {
    _resetKeyboardTimer(); // ✅ REINICIA TIMER DO TECLADO
    if (_enteredPassword.isNotEmpty) {
      setState(() {
        _enteredPassword = _enteredPassword.substring(
          0,
          _enteredPassword.length - 1,
        );
      });
    }
  }

  // 2. MUDANÇA: Novo comportamento ao tocar nos itens da barra
  void _onItemTapped(int index) {
    _resetTimerOnInteraction(); // ✅ REINICIA TIMER
    // Se o usuário está voltando para a tela de Avaliação (índice 0)
    // ✅ VERIFICA SE É A ABA DE ESTATÍSTICAS (índice 2)
    if (index == 2) {
      _showPasswordInput();
      return; // Impede a navegação imediata
    }
    if (index == 0) {
      final defaultShift = _calculateDefaultShift();

      // Se o turno atual for diferente do padrão, reseta para o padrão.
      if (_currentShift != defaultShift) {
        setState(() {
          _selectedIndex = index;
          _currentShift = defaultShift;
        });
        _resetHomeScreen();
        return; // Sai da função
      }
      _resetHomeScreen(); // Reseta a tela de avaliação
    }

    // Comportamento padrão (se não houve reset de turno):
    setState(() {
      _selectedIndex = index;
    });
  }

  // Função chamada pelo menu para trocar o turno (permanece inalterada)
  void _selectShift(int shift) {
    _resetTimerOnInteraction(); // ✅ REINICIA TIMER
    setState(() {
      _currentShift = shift;
    });
  }

  void _navigateToFeedbackScreen(int rating, int tabIndex) {
    // ✅ ADICIONE uma animação suave:
    Future.delayed(Duration.zero, () {
      setState(() {
        _selectedRatingFromHome = rating;
        _initialTabIndex = tabIndex;
        _selectedIndex = 1;
      });
    });
  }

  void _resetHomeScreen() {
    setState(() {
      _selectedRatingFromHome = null;
      _initialTabIndex = null;
      _selectedIndex = 0; // VOLTA PARA A TELA INICIAL (RatingSelectionScreen)
    });
  }

  // ✅ CONSTRÓI O DIALOG DE SENHA
  Widget _buildPasswordDialog() {
    return GestureDetector(
      onTap: _resetKeyboardTimer, // ✅ DETECTA TOQUES NO DIALOG
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: _resetKeyboardTimer, // ✅ DETECTA TOQUES NO CARD
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Senha de Acesso',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 111, 136, 63),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Digite a senha para acessar as estatísticas:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // ✅ INDICADOR DE DÍGITOS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return GestureDetector(
                        onTap:
                            _resetKeyboardTimer, // ✅ DETECTA TOQUES NOS INDICADORES
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            color: index < _enteredPassword.length
                                ? const Color.fromARGB(255, 0, 0, 0)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              index < _enteredPassword.length ? '•' : '',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),

                  // ✅ TECLADO NUMÉRICO
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (int i = 1; i <= 9; i++)
                        _buildNumberButton(i.toString()),
                      _buildEmptyButton(),
                      _buildNumberButton('0'),
                      _buildBackspaceButton(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ✅ BOTÕES DE AÇÃO
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cancelPassword,
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _enteredPassword.isNotEmpty
                              ? _checkPassword
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              111,
                              136,
                              63,
                            ),
                          ),
                          child: const Text(
                            'Verificar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ BOTÃO NUMÉRICO
  Widget _buildNumberButton(String number) {
    return ElevatedButton(
      onPressed: () {
        _resetKeyboardTimer(); // ✅ REINICIA TIMER AO CLICAR
        _addDigit(number);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        number,
        style: const TextStyle(
          fontSize: 18,
          color: Color.fromARGB(255, 0, 0, 0),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ✅ BOTÃO VAZIO (para alinhamento)
  Widget _buildEmptyButton() {
    return const SizedBox.shrink();
  }

  // ✅ BOTÃO DE APAGAR
  Widget _buildBackspaceButton() {
    return ElevatedButton(
      onPressed: () {
        _resetKeyboardTimer(); // ✅ REINICIA TIMER AO CLICAR
        _removeDigit();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Icon(Icons.backspace, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      GestureDetector(
        onTap: _resetTimerOnInteraction,
        behavior: HitTestBehavior.translucent,
        child: RatingSelectionScreen(
          onRatingSelected: _navigateToFeedbackScreen,
          selectedRating: _selectedRatingFromHome,
          currentShift: _currentShift,
        ),
      ),
      GestureDetector(
        onTap: _resetTimerOnInteraction,
        behavior: HitTestBehavior.translucent,
        child: RatingScreen(
          currentShift: _currentShift,
          initialRating: _selectedRatingFromHome ?? 0,
          initialTabIndex: _initialTabIndex ?? 0,
          onBackToHome: _resetHomeScreen,
        ),
      ),
      GestureDetector(
        onTap: _resetTimerOnInteraction,
        behavior: HitTestBehavior.translucent,
        child: StatisticsScreen(currentShift: _currentShift),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Avaliação do Restaurante (Turno $_currentShift)'
              : 'Estatísticas das Avaliações (Turno $_currentShift)',
          style: const TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 111, 136, 63),
        elevation: 4,
        actions: _selectedIndex == 1
            ? [
                IconButton(
                  icon: const Icon(
                    Icons.access_time_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _resetTimerOnInteraction();
                    setState(() {
                      _selectedIndex = 0;
                    });
                    _resetHomeScreen();
                  },
                ),
              ]
            : [
                PopupMenuButton<int>(
                  onSelected: _selectShift,
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                    const PopupMenuItem<int>(
                      value: 1,
                      child: Text('Turno 1 (Manhã/Tarde)'),
                    ),
                    const PopupMenuItem<int>(
                      value: 2,
                      child: Text('Turno 2 (Noite/Madrugada)'),
                    ),
                  ],
                  icon: const Icon(
                    Icons.access_time_filled,
                    color: Colors.white,
                  ),
                ),
              ],
      ),
      body: Stack(
        children: [
          // CONTEÚDO PRINCIPAL
          GestureDetector(
            onTap: _resetTimerOnInteraction,
            behavior: HitTestBehavior.translucent,
            child: Center(child: widgetOptions.elementAt(_selectedIndex)),
          ),

          // ✅ DIALOG DE SENHA (se necessário)
          if (_showPasswordDialog) _buildPasswordDialog(),
        ],
      ),
      bottomNavigationBar: GestureDetector(
        onTap: _resetTimerOnInteraction,
        behavior: HitTestBehavior.translucent,
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_emoticon_rounded),
              label: 'Avaliações',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_rounded),
              label: 'Feedbacks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Estatísticas',
            ),
          ],
          selectedLabelStyle: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 14.0),
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.green.shade700,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
// ===================================================================
// TELA 1: AVALIAÇÃO (COM IMAGEM DE FUNDO E FLUXO CONDICIONAL)
// ===================================================================

class RatingScreen extends StatefulWidget {
  // ✅ ADICIONADO: Recebe a nota inicial e o índice da aba
  final int currentShift;
  final int initialRating;
  final int initialTabIndex;

  final VoidCallback onBackToHome;

  const RatingScreen({
    super.key,
    required this.currentShift,
    required this.initialRating,
    required this.initialTabIndex,
    required this.onBackToHome,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  // O TabController foi removido na versão anterior, então mantemos este layout.
  late TabController _tabController; // Vai ser inicializado no initState

  // Variáveis de estado
  double _detailedOpacity = 0.0;
  bool _showDetailed = true;
  int _selectedStars = 0;
  final Set<String> _pendingDetailedPhrases = {};

  // NOVIDADE: Controller para o campo de texto do comentário
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // ✅ CORREÇÃO: Inicializa com o valor passado ou usa 0 como padrão.
    _selectedStars = widget.initialRating ?? 0;

    // Define a aba inicial com o valor passado ou usa 0 (Positivo) como padrão.
    final int initialTab =
        widget.initialTabIndex ?? ((_selectedStars >= 4) ? 0 : 1);

    // O código aqui presume que o DefaultTabController está no build.
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handlePhraseSelection(String phrase) {
    setState(() {
      if (_pendingDetailedPhrases.contains(phrase)) {
        _pendingDetailedPhrases.remove(phrase);
      } else {
        _pendingDetailedPhrases.add(phrase);
      }
    });
  }

  void _handleStarClick(int star, BuildContext tabContext) {
    setState(() {
      // ✅ CORREÇÃO: Apenas a estrela clicada é armazenada (comportamento "radio button")
      _selectedStars = star;
    });

    // Lógica para determinar o índice da aba:
    int targetIndex;

    if (star >= 4) {
      // 4 ou 5 estrelas: Feedback Positivo (Índice 0)
      targetIndex = 0;
    } else {
      // 1, 2 ou 3 estrelas: Feedback Negativo (Índice 1)
      targetIndex = 1;
    }

    // Navega para a aba de destino usando o contexto corrigido:
    DefaultTabController.of(tabContext).animateTo(targetIndex);
  }

  void _sendRating(BuildContext context) {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecione uma nota geral (estrelas) antes de enviar.',
          ),
        ),
      );
      return;
    }

    final appData = Provider.of<AppData>(context, listen: false);
    final currentShift = widget.currentShift;

    // 1. COLETAR TODOS OS DADOS DA AVALIAÇÃO
    final comment = _commentController.text;

    // 2. NOVIDADE: Adicionar o registro de transação ao AppData (que salva automaticamente)
    appData.addEvaluationRecord(
      star: _selectedStars,
      shift: currentShift,
      // Usamos o método isPositive do AppData para classificar as frases:
      positiveFeedbacks: _pendingDetailedPhrases
          .where((p) => appData.isPositive(p))
          .toSet(),
      negativeFeedbacks: _pendingDetailedPhrases
          .where((p) => !appData.isPositive(p))
          .toSet(),
      comment: _commentController.text, // Adiciona o comentário
    );

    // 3. Feedback e Reset
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obrigado pela avaliação!'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() {
      _selectedStars = 0;
      _pendingDetailedPhrases.clear();
      _commentController.clear();
    });
    widget.onBackToHome();

    // Voltar para a tela inicial após 1 segundo
    Future.delayed(const Duration(milliseconds: 1000), () {
      // Chama o callback para voltar à home
      widget.onBackToHome();

      // GARANTE que volta para a aba de avaliações (índice 0)
      if (mounted) {
        // Navega de volta para a tela inicial
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
      length: 2,
      child: Scaffold(
        body: Stack(
          children: [
            // ✅ FUNDO RESPONSIVO
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.25,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.modulate,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: screenWidth * 0.7,
                        height: screenWidth * 0.7,
                        child: Image.asset(
                          'assets/images/costa_feedbacks_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ✅ CONTEÚDO RESPONSIVO
            Column(
              children: [
                // ✅ TAB BAR RESPONSIVO
                Container(
                  color: Colors.transparent,
                  child: TabBar(
                    labelColor: const Color(0xFF3F4533),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF3F4533),
                    labelStyle: TextStyle(
                      fontSize: isSmallScreen ? 14 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: isSmallScreen ? 14 : 18,
                    ),
                    tabs: const [
                      Tab(text: 'Feedback Positivo'),
                      Tab(text: 'Feedback Negativo'),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      DetailedFeedbackTab(
                        sentiment: 'Positiva',
                        onPhraseSelected: _handlePhraseSelection,
                        selectedPhrases: _pendingDetailedPhrases,
                      ),
                      DetailedFeedbackTab(
                        sentiment: 'Negativa',
                        onPhraseSelected: _handlePhraseSelection,
                        selectedPhrases: _pendingDetailedPhrases,
                      ),
                    ],
                  ),
                ),

                // ✅ COMENTÁRIO RESPONSIVO
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Escreva um comentário (Opcional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText:
                          'Digite aqui suas sugestões, elogios ou críticas...',
                    ),
                  ),
                ),

                // ✅ BOTÃO RESPONSIVO
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: ElevatedButton(
                    onPressed: () => _sendRating(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 111, 136, 63),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 15,
                        horizontal: 20,
                      ),
                      minimumSize: Size(
                        double.infinity,
                        isSmallScreen ? 50 : 60,
                      ),
                    ),
                    child: Text(
                      'Enviar Avaliação',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// WIDGET NOVO: DetailedFeedbackTab (Aba de Detalhes Positivos/Negativos)
// ===================================================================

class DetailedFeedbackTab extends StatelessWidget {
  final String sentiment;
  final PhraseSelectedCallback onPhraseSelected;
  final Set<String> selectedPhrases;

  const DetailedFeedbackTab({
    super.key,
    required this.sentiment,
    required this.onPhraseSelected,
    required this.selectedPhrases,
  });

  // Frases de feedback
  final Map<String, List<String>> _phrases = const {
    'Comida Positiva': ['Bem Temperada', 'Comida quente', 'Boa Variedade'],
    'Comida Negativa': ['Sem Sal/Insossa', 'Comida Fria', 'Aparência Estranha'],
    'Serviço Positiva': [
      'Funcionários Atenciosos',
      'Reposição Rápida',
      'Organização Eficiente',
    ],
    'Serviço Negativa': [
      'Atendimento Lento',
      'Demora na Limpeza',
      'Filas Grandes',
    ],
    'Ambiente Positiva': [
      'Ambiente Limpo',
      'Climatização Boa',
      'Ambiente Silencioso',
    ],
    'Ambiente Negativa': [
      'Ambiente Sujo',
      'Climatização Ruim',
      'Ambiente Barulhento',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ CATEGORIAS RESPONSIVAS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Comida', 'Serviço', 'Ambiente']
                .map(
                  (c) => Expanded(
                    child: Center(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 18,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          SizedBox(height: screenWidth * 0.04),

          // ✅ BOTÕES RESPONSIVOS
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ['Comida', 'Serviço', 'Ambiente']
                .map(
                  (category) => Expanded(
                    child: CategoryFeedbackColumn(
                      category: category,
                      sentiment: sentiment,
                      phrases: _phrases,
                      onPhraseSelected: onPhraseSelected,
                      selectedPhrases: selectedPhrases,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// WIDGET NOVO: CategoryFeedbackColumn (Organiza os botões em 3 colunas)
// ===================================================================

class CategoryFeedbackColumn extends StatelessWidget {
  // MUDANÇA: Voltamos para StatelessWidget
  final String category;
  final String sentiment; // 'Positiva' ou 'Negativa'
  final Map<String, List<String>> phrases;
  final PhraseSelectedCallback onPhraseSelected;
  final Set<String> selectedPhrases;

  const CategoryFeedbackColumn({
    super.key,
    required this.category,
    required this.sentiment,
    required this.phrases,
    required this.onPhraseSelected,
    required this.selectedPhrases,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = sentiment == 'Positiva';
    final Color baseColor = isPositive ? Colors.green : Colors.red;
    final List<String> currentPhrases = phrases['$category $sentiment'] ?? [];

    // ✅ DETECÇÃO DE TAMANHO DE TELA
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    // ✅ LARGURA MÁXIMA RESPONSIVA
    final maxButtonWidth = isSmallScreen
        ? screenWidth * 0.9
        : (isLargeScreen ? 200.0 : double.infinity);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
      ), // ✅ PADDING RESPONSIVO
      child: Column(
        children: currentPhrases
            .map(
              (phrase) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxButtonWidth),
                child: _buildButton(
                  phrase: phrase,
                  baseColor: baseColor,
                  context: context,
                  isSelected: selectedPhrases.contains(phrase),
                  onTap: () => onPhraseSelected(phrase),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ✅ MÉTODO _buildButton RESPONSIVO
  Widget _buildButton({
    required String phrase,
    required Color baseColor,
    required BuildContext context,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // ✅ DETECÇÃO DE TAMANHO
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    // Variáveis de cor e estado
    final bool isGreen = baseColor == Colors.green;
    final Color selectedColor = isGreen
        ? Colors.green.shade700
        : Colors.red.shade700;
    final Color unselectedColor = Colors.white;
    final Color primaryBorderColor = isGreen
        ? Colors.green.shade700
        : Colors.red.shade700;
    final Color unselectedTextColor = Colors.black87;

    // ✅ QUEBRA DE LINHA RESPONSIVA
    String formattedPhrase = phrase;
    int firstSpaceIndex = phrase.indexOf(' ');

    if (firstSpaceIndex != -1) {
      formattedPhrase =
          phrase.substring(0, firstSpaceIndex) +
          '\n' +
          phrase.substring(firstSpaceIndex + 1);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: screenWidth * 0.02,
      ), // ✅ ESPAÇAMENTO RESPONSIVO
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : unselectedColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryBorderColor : Colors.grey.shade400,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          // ✅ PADDING RESPONSIVO
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03,
            vertical: isSmallScreen ? 8 : (isLargeScreen ? 12 : 10),
          ),
          alignment: Alignment.center,
          child: Text(
            formattedPhrase,
            textAlign: TextAlign.center,
            // ✅ TEXTO RESPONSIVO
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : (isLargeScreen ? 17 : 16),
              color: isSelected ? Colors.white : unselectedTextColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// TELA 2: ESTATÍSTICAS (Gráfico)
// ===================================================================

class StatisticsScreen extends StatefulWidget {
  final int currentShift;
  const StatisticsScreen({super.key, required this.currentShift});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with WidgetsBindingObserver {
  // ✅ ADICIONE: Estado para controlar o tipo de gráfico
  String _selectedView = 'Total'; // 'Total', 'Média', 'MaisAvaliado'

  OverlayEntry? _exportOverlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeAllOverlays();
    super.dispose();
  }

  // ✅ FECHA TODOS OS OVERLAYS/POP-UPS
  void _closeAllOverlays() {
    _exportOverlayEntry?.remove();
    _exportOverlayEntry = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _closeAllOverlays();
    }
  }

  void _changeView(String view) {
    setState(() {
      _selectedView = view;
    });
  }

  String _getDetailCountText(int count) {
    if (count == 1) {
      return '$count vez';
    } else {
      return '$count vezes';
    }
  }

  bool _isPositiveFeedback(String phrase) {
    const phrasesMap = {
      'Bem Temperada': true,
      'Comida quente': true,
      'Boa Variedade': true,
      'Sem Sal/Insossa': false,
      'Comida Fria': false,
      'Aparência Estranha': false,
      'Funcionários Atenciosos': true,
      'Reposição Rápida': true,
      'Organização Eficiente': true,
      'Atendimento Lento': false,
      'Demora na Limpeza': false,
      'Filas Grandes': false,
      'Ambiente Limpo': true,
      'Climatização Boa': true,
      'Ambiente Silencioso': true,
      'Ambiente Sujo': false,
      'Climatização Ruim': false,
      'Ambiente Barulhento': false,
    };
    return phrasesMap[phrase] ?? false;
  }

  // ✅ MÉTODO PARA CONVERTER NÚMERO PARA NOME DA CATEGORIA
  String getCategoryName(int stars) {
    switch (stars) {
      case 1:
        return 'Péssimo';
      case 2:
        return 'Ruim';
      case 3:
        return 'Neutro';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return '$stars estrelas';
    }
  }

  // ✅ ADICIONE os botões de controle
  Widget _buildViewSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      children: [
        if (isSmallScreen) // ✅ LAYOUT VERTICAL PARA TELAS PEQUENAS
          Column(
            children: [
              _buildViewButton('Total', _selectedView == 'Total'),
              SizedBox(height: 8),
              _buildViewButton('Média', _selectedView == 'Média'),
              SizedBox(height: 8),
              _buildViewButton(
                'Mais Avaliado',
                _selectedView == 'Mais Avaliado',
              ),
            ],
          )
        else // ✅ LAYOUT HORIZONTAL PARA TELAS MÉDIAS/GRANDES
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildViewButton('Total', _selectedView == 'Total'),
              SizedBox(width: 10),
              _buildViewButton('Média', _selectedView == 'Média'),
              SizedBox(width: 10),
              _buildViewButton(
                'Mais Avaliado',
                _selectedView == 'Mais Avaliado',
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildViewButton(String text, bool isSelected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return ElevatedButton(
      onPressed: () => _changeView(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color.fromARGB(255, 111, 136, 63)
            : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 8 : 10,
        ),
        minimumSize: Size(
          isSmallScreen ? double.infinity : 0,
          isSmallScreen ? 45 : 40,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int selectedShift = widget.currentShift;

    // ✅ DETECÇÃO DE TAMANHO
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    return Consumer<AppData>(
      builder: (context, appData, child) {
        final starRatings = appData.getTodayStarRatings(selectedShift);
        final detailedRatings = appData.getTodayDetailedRatings(selectedShift);
        final totalRatings = appData.getTodayTotalStarRatings(selectedShift);

        final int totalDetailedFeedbacks = detailedRatings.values.fold(
          0,
          (sum, count) => sum + count,
        );
        final now = DateTime.now();
        final todayFormatted = '${now.day}/${now.month}/${now.year}';

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SingleChildScrollView(
                    // ✅ PADDING RESPONSIVO
                    padding: EdgeInsets.all(
                      isSmallScreen ? 20 : (isLargeScreen ? 40 : 32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // 1. TÍTULO CENTRALIZADO RESPONSIVO
                        Text(
                          'Distribuição de Reações (Hoje)',
                          style: TextStyle(
                            fontSize: isSmallScreen
                                ? 24
                                : (isLargeScreen ? 35 : 30),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // ✅ MAIS ESPAÇO ENTRE TÍTULO E SUBTÍTULO
                        SizedBox(height: isSmallScreen ? 12 : 16),

                        Text(
                          'Data: $todayFormatted - Total de Avaliações: $totalRatings',
                          style: TextStyle(
                            fontSize: isSmallScreen
                                ? 14
                                : (isLargeScreen ? 18 : 16),
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // ✅ MAIS ESPAÇO ENTRE SUBTÍTULO E GRÁFICO
                        SizedBox(height: isSmallScreen ? 28 : 50),

                        // 2. GRÁFICO + LEGENDA
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 500;

                            // ✅ TAMANHO DO GRÁFICO FIXO PARA GARANTIR VISIBILIDADE
                            final double chartSize = isSmallScreen
                                ? 180.0
                                : (isLargeScreen ? 280.0 : 220.0);

                            final pieChartWidget = totalRatings == 0
                                ? Container(
                                    height: chartSize,
                                    child: const Center(
                                      child: Text(
                                        'Nenhuma avaliação de estrela ainda.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    width: chartSize,
                                    height: chartSize,
                                    child: PieChart(
                                      PieChartData(
                                        sections: _buildStarSections(
                                          appData,
                                          starRatings,
                                          totalRatings,
                                          chartSize,
                                        ),
                                        sectionsSpace: 2.0,
                                        centerSpaceRadius: isSmallScreen
                                            ? 35.0
                                            : 50.0,
                                        borderData: FlBorderData(show: false),
                                      ),
                                    ),
                                  );

                            if (isWide) {
                              return Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    pieChartWidget,
                                    SizedBox(
                                      width: isSmallScreen ? 20.0 : 40.0,
                                    ),
                                    SizedBox(
                                      width: isSmallScreen ? 120.0 : 180.0,
                                      child: _buildStarLegend(
                                        appData,
                                        starRatings,
                                        totalRatings,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  pieChartWidget,

                                  // ✅ MAIS ESPAÇO ENTRE GRÁFICO E LEGENDA
                                  SizedBox(height: isSmallScreen ? 20 : 28),

                                  _buildStarLegend(
                                    appData,
                                    starRatings,
                                    totalRatings,
                                  ),
                                ],
                              );
                            }
                          },
                        ),

                        // ✅ MAIS ESPAÇO ENTRE GRÁFICO E DIVIDER
                        SizedBox(height: isSmallScreen ? 50 : 70),

                        const Divider(),

                        // 3. DETALHES (Frequência) RESPONSIVO
                        Text(
                          'Frequência dos Detalhes',
                          style: TextStyle(
                            fontSize: isSmallScreen
                                ? 20
                                : (isLargeScreen ? 25 : 22),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),

                        // ✅ ESPAÇO ENTRE TÍTULO E SUBTÍTULO DOS DETALHES
                        SizedBox(height: isSmallScreen ? 8 : 12),

                        Text(
                          'Total de Feedbacks: $totalDetailedFeedbacks',
                          style: TextStyle(
                            fontSize: isSmallScreen
                                ? 14
                                : (isLargeScreen ? 19 : 16),
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.left,
                        ),

                        // ✅ ESPAÇO ENTRE SUBTÍTULO E LISTA
                        SizedBox(height: isSmallScreen ? 16 : 20),

                        _buildDetailedStats(detailedRatings),

                        // ✅ BOTÕES E GRÁFICOS CONDICIONAIS RESPONSIVOS
                        SizedBox(height: isSmallScreen ? 30 : 45),

                        const Divider(),

                        // ✅ ESPAÇO ENTRE DIVIDER E TÍTULO
                        SizedBox(height: isSmallScreen ? 8 : 12),

                        Text(
                          'Análise dos Últimos 7 Dias',
                          style: TextStyle(
                            fontSize: isSmallScreen
                                ? 20
                                : (isLargeScreen ? 25 : 22),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // ✅ ESPAÇO ENTRE TÍTULO E BOTÕES
                        SizedBox(height: isSmallScreen ? 18 : 24),

                        _buildViewSelector(),

                        // ✅ ESPAÇO ENTRE BOTÕES E GRÁFICOS
                        SizedBox(height: isSmallScreen ? 20 : 28),

                        // ✅ GRÁFICOS CONDICIONAIS
                        if (_selectedView == 'Total')
                          _buildLast7DaysBarChart(appData, selectedShift),
                        if (_selectedView == 'Média')
                          _buildAverageBarChart(appData, selectedShift),
                        if (_selectedView == 'Mais Avaliado')
                          _buildMostRatedBarChart(appData, selectedShift),
                      ],
                    ),
                  ),
                ),
              ),
              // ✅ BOTÃO DE EXPORTAÇÃO
              _buildExportButton(context),
            ],
          ),
        );
      },
    );
  }

  // ✅ MODIFIQUE O MÉTODO _buildExportButton para usar Navigator
  Widget _buildExportButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _exportDataWithSafety(context),
        icon: const Icon(Icons.download_rounded),
        label: const Text(
          'Exportar Dados em CSV',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 111, 136, 63),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 60),
        ),
      ),
    );
  }

  // ✅ NOVO MÉTODO SEGURO PARA EXPORTAÇÃO
  void _exportDataWithSafety(BuildContext context) {
    // Fecha qualquer pop-up existente antes de abrir novo
    Navigator.of(context).popUntil((route) => route.isFirst);

    final appData = Provider.of<AppData>(context, listen: false);
    appData.exportCSV(context);
  }

  void _exportData(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    appData.exportCSV(context);
  }

  Widget _buildQuickAccessButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 8.0),
      child: OutlinedButton.icon(
        onPressed: () {
          final appData = Provider.of<AppData>(context, listen: false);
          appData.openLastSavedFile(context);
        },
        icon: const Icon(Icons.folder_open, size: 18),
        label: const Text('Abrir Pasta do Último Arquivo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color.fromARGB(255, 111, 136, 63),
          side: const BorderSide(color: Color.fromARGB(255, 111, 136, 63)),
        ),
      ),
    );
  }

  // ✅ MOSTRAR OPÇÕES DE EXPORTAÇÃO
  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Como deseja exportar?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Opção 1: Escolher pasta
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.blue),
              title: const Text('Escolher pasta para salvar'),
              subtitle: const Text('Selecione qualquer pasta do dispositivo'),
              onTap: () {
                Navigator.pop(context);
                _exportWithChoice(context);
              },
            ),
            // Opção 2: Downloads
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Salvar no dispositivo'),
              subtitle: const Text('Salva automaticamente no dispositivo'),
              onTap: () {
                Navigator.pop(context);
                _exportToDownloads(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportWithChoice(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    appData.exportCSV(context);
  }

  void _exportToDownloads(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    appData.exportToDownloads(context);
  }

  // Seções para o Gráfico de Pizza de Estrelas
  List<PieChartSectionData> _buildStarSections(
    AppData appData,
    Map<int, int> starRatings,
    int totalRatings,
    double chartSize,
  ) {
    return starRatings.entries
        .map((entry) {
          final int star = entry.key;
          final int count = entry.value;
          final double percentage = totalRatings > 0
              ? (count / totalRatings) * 100
              : 0;

          if (count == 0) return null;

          return PieChartSectionData(
            color: appData.pieColors[star - 1],
            value: percentage,
            radius: chartSize * 0.4, // ✅ RAIO PROPORCIONAL
            title: '${percentage.toStringAsFixed(0)}%',
            titleStyle: TextStyle(
              fontSize: chartSize * 0.06, // ✅ TEXTO RESPONSIVO
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        })
        .whereType<PieChartSectionData>()
        .toList();
  }

  static List<String> _sentimentLabels = [
    'Péssimo',
    'Ruim',
    'Neutro',
    'Bom',
    'Excelente',
  ];

  Widget _buildStarLegend(
    AppData appData,
    Map<int, int> starRatings,
    int totalRatings,
  ) {
    final total = totalRatings;

    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: starRatings.entries.map((entry) {
          final int star = entry.key;
          final int count = entry.value;
          final double percentage = total > 0 ? (count / total) * 100 : 0;

          final String label = _sentimentLabels[star - 1];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  color: appData.pieColors[star - 1],
                  margin: const EdgeInsets.only(right: 20),
                ),
                Text('$label: ${count}', style: const TextStyle(fontSize: 20)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Lista de detalhes de avaliação
  Widget _buildDetailedStats(Map<String, int> detailedRatings) {
    if (detailedRatings.isEmpty) {
      return const Center(
        child: Text('Nenhum detalhe de feedback registrado.'),
      );
    }

    final sortedEntries = detailedRatings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final isPositive = _isPositiveFeedback(entry.key);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  color: isPositive
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                ),
              ),
              Text(
                _getDetailCountText(entry.value),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ GRÁFICO DE TOTAL
  Widget _buildLast7DaysBarChart(AppData appData, int selectedShift) {
    final dailyData = appData.getLast7DaysStarRatings(selectedShift);
    final sortedDays = dailyData.keys.toList()..sort((a, b) => a.compareTo(b));

    final List<String> dayLabels = sortedDays
        .map((day) => _getDayLabel(day))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              maxY: _getMaxYValue(dailyData),
              groupsSpace: 12,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.grey[800]!,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final star = rodIndex + 1;
                    final count = rod.toY.toInt();
                    final dayIndex = groupIndex;
                    final day = sortedDays[dayIndex];
                    final dayLabel = _getDayLabel(day);
                    final categoryName = getCategoryName(star);

                    return BarTooltipItem(
                      '$dayLabel\n$categoryName: $count avaliação${count == 1 ? '' : 's'}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dayLabels[value.toInt()],
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: _buildBarGroups(dailyData, sortedDays),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildBarChartLegend(),
      ],
    );
  }

  // ✅ GRÁFICO DE MÉDIA
  Widget _buildAverageBarChart(AppData appData, int selectedShift) {
    final averageData = appData.getLast7DaysAverageRatings(selectedShift);
    final sortedDays = averageData.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final List<String> dayLabels = sortedDays
        .map((day) => _getDayLabel(day))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          'Média das avaliações por dia',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              maxY: 5.0,
              groupsSpace: 12,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.grey[800]!,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dayIndex = groupIndex;
                    final day = sortedDays[dayIndex];
                    final average = averageData[day] ?? 0.0;
                    final categoryName = getCategoryName(average.round());

                    return BarTooltipItem(
                      '${_getDayLabel(day)}\nMédia: ${average.toStringAsFixed(1)} ($categoryName)',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dayLabels[value.toInt()],
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min ||
                          value == meta.max ||
                          value == 2.5) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: sortedDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final average = averageData[day] ?? 0.0;

                Color getColorForAverage(double avg) {
                  if (avg < 2.0) return Colors.red.shade700;
                  if (avg < 3.0) return Colors.deepOrange;
                  if (avg < 4.0) return Colors.amber;
                  if (avg < 4.5) return Colors.lightGreen;
                  return Colors.green.shade700;
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      fromY: 0,
                      toY: average,
                      color: getColorForAverage(average),
                      width: 20,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ GRÁFICO DO MAIS AVALIADO
  Widget _buildMostRatedBarChart(AppData appData, int selectedShift) {
    final mostRatedData = appData.getLast7DaysMostRated(selectedShift);
    final sortedDays = mostRatedData.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final List<String> dayLabels = sortedDays
        .map((day) => _getDayLabel(day))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          'Categoria mais avaliada por dia',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              maxY: _getMaxYValueMostRated(mostRatedData),
              groupsSpace: 12,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.grey[800]!,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dayIndex = groupIndex;
                    final day = sortedDays[dayIndex];
                    final data = mostRatedData[day]!;
                    final star = data['star'] as int;
                    final count = data['count'] as int;
                    final categoryName = getCategoryName(star);

                    return BarTooltipItem(
                      '${_getDayLabel(day)}\n$categoryName: $count avaliação${count == 1 ? '' : 's'}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dayLabels[value.toInt()],
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min ||
                          value == meta.max ||
                          value == meta.max / 2) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: sortedDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final data = mostRatedData[day]!;
                final star = data['star'] as int;
                final count = data['count'] as int;

                Color getColorForStar(int star) {
                  switch (star) {
                    case 1:
                      return Colors.red.shade700;
                    case 2:
                      return Colors.deepOrange;
                    case 3:
                      return Colors.amber;
                    case 4:
                      return Colors.lightGreen;
                    case 5:
                      return Colors.green.shade700;
                    default:
                      return Colors.grey;
                  }
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      fromY: 0,
                      toY: count.toDouble(),
                      color: getColorForStar(star),
                      width: 20,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // Métodos auxiliares
  double _getMaxYValue(Map<DateTime, Map<int, int>> dailyData) {
    double max = 0;
    for (var dayData in dailyData.values) {
      final dayMax = dayData.values.reduce((a, b) => a > b ? a : b);
      if (dayMax > max) max = dayMax.toDouble();
    }
    return max + 2;
  }

  double _getMaxYValueMostRated(
    Map<DateTime, Map<String, dynamic>> mostRatedData,
  ) {
    double max = 0;
    for (var data in mostRatedData.values) {
      final count = data['count'] as int;
      if (count > max) max = count.toDouble();
    }
    return max + 1;
  }

  List<BarChartGroupData> _buildBarGroups(
    Map<DateTime, Map<int, int>> dailyData,
    List<DateTime> sortedDays,
  ) {
    return sortedDays.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;
      final dayData = dailyData[day]!;

      return BarChartGroupData(
        x: index,
        groupVertically: false,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: dayData[1]?.toDouble() ?? 0,
            color: Colors.red.shade700,
            width: 10,
          ),
          BarChartRodData(
            fromY: 0,
            toY: dayData[2]?.toDouble() ?? 0,
            color: Colors.deepOrange,
            width: 10,
          ),
          BarChartRodData(
            fromY: 0,
            toY: dayData[3]?.toDouble() ?? 0,
            color: Colors.amber,
            width: 10,
          ),
          BarChartRodData(
            fromY: 0,
            toY: dayData[4]?.toDouble() ?? 0,
            color: Colors.lightGreen,
            width: 10,
          ),
          BarChartRodData(
            fromY: 0,
            toY: dayData[5]?.toDouble() ?? 0,
            color: Colors.green.shade700,
            width: 10,
          ),
        ],
      );
    }).toList();
  }

  Widget _buildBarChartLegend() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.red.shade700, 'Péssimo'),
            _buildLegendItem(Colors.deepOrange, 'Ruim'),
            _buildLegendItem(Colors.amber, 'Neutro'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.lightGreen, 'Bom'),
            _buildLegendItem(Colors.green.shade700, 'Excelente'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _getDayLabel(DateTime day) {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final twoDaysAgo = yesterday.subtract(const Duration(days: 1));

    if (day == yesterday) return 'Ontem';
    if (day == twoDaysAgo) return '2 dias atrás';
    return '${day.day}/${day.month}';
  }
}

// Mantenha esta cor institucional definida no topo do seu main.dart
const Color costaFoodsColor = Color(0xFF3F4533);

// NOVO WIDGET (Substitui HelloScreen): A tela inicial de seleção da nota
// NOVO WIDGET (Substitui HelloScreen): A tela inicial de seleção da nota
class RatingSelectionScreen extends StatefulWidget {
  final Function(int, int) onRatingSelected;
  final int? selectedRating;
  final int currentShift;

  const RatingSelectionScreen({
    super.key,
    required this.onRatingSelected,
    this.selectedRating,
    required this.currentShift,
  });

  @override
  State<RatingSelectionScreen> createState() => _RatingSelectionScreenState();
}

class _RatingSelectionScreenState extends State<RatingSelectionScreen> {
  int _selectedStars = 0;

  final List<String> _ratingEmojis = const ['😠', '😟', '😐', '🙂', '😍'];

  @override
  void initState() {
    super.initState();
    _selectedStars = widget.selectedRating ?? 0;
  }

  void _handleEmojiClick(int star) {
    setState(() {
      _selectedStars = star;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      final int initialTab = (star >= 4) ? 0 : 1;
      widget.onRatingSelected(star, initialTab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    return Stack(
      children: [
        // ✅ IMAGEM DE FUNDO RESPONSIVA
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.25,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.modulate,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: screenWidth * 0.8,
                    height: screenWidth * 0.8,
                    child: Image.asset(
                      'assets/images/costa_feedbacks_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ✅ CONTEÚDO PRINCIPAL RESPONSIVO - AGORA CORRETAMENTE CENTRALIZADO
        Positioned.fill(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ TÍTULO RESPONSIVO
                  Text(
                    'Qual sua experiência geral?',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 28 : (isLargeScreen ? 44 : 36),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // ✅ DATA RESPONSIVA
                  Consumer<AppData>(
                    builder: (context, appData, child) {
                      final now = DateTime.now();
                      final todayFormatted =
                          '${now.day}/${now.month}/${now.year}';
                      return Text(
                        'Hoje: $todayFormatted',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 18,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // ✅ EMOJIS RESPONSIVOS E CORRETAMENTE CENTRALIZADOS
                  ...List.generate(5, (index) {
                    final int starValue = index + 1;
                    final String currentEmoji = _ratingEmojis[index];
                    final bool isSelected = starValue == _selectedStars;

                    final List<String> legendas = [
                      'Péssimo',
                      'Ruim',
                      'Neutro',
                      'Bom',
                      'Excelente',
                    ];
                    final String legendaAtual = legendas[index];

                    return Container(
                      width: screenWidth * 0.9, // ✅ LARGURA CONTROLADA
                      margin: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.01,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment
                            .center, // ✅ CENTRALIZA TODO O CONTEÚDO
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize
                            .min, // ✅ IMPEDE QUE OCUPE LARGURA TOTAL
                        children: [
                          // ✅ EMOJI AGORA CENTRALIZADO E MAIOR
                          Container(
                            width: screenWidth * 0.2,
                            child: IconButton(
                              onPressed: () => _handleEmojiClick(starValue),
                              padding:
                                  EdgeInsets.zero, // ✅ REMOVE PADDING EXTRA
                              style: ButtonStyle(
                                side: WidgetStateProperty.all(BorderSide.none),
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color?>((
                                      Set<WidgetState> states,
                                    ) {
                                      return isSelected
                                          ? Colors.amber.withOpacity(0.3)
                                          : Colors.transparent;
                                    }),
                                shape: WidgetStateProperty.all<OutlinedBorder>(
                                  const CircleBorder(),
                                ),
                                overlayColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                              icon: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 1.0,
                                  end: isSelected
                                      ? 1.3
                                      : 1.0, // ✅ AUMENTEI A ANIMAÇÃO DE SELEÇÃO
                                ),
                                duration: const Duration(milliseconds: 200),
                                builder:
                                    (
                                      BuildContext context,
                                      double scale,
                                      Widget? child,
                                    ) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: Text(
                                          currentEmoji,
                                          style: TextStyle(
                                            // ✅ TAMANHO AUMENTADO E PROPORCIONAL
                                            fontSize: isSmallScreen
                                                ? 50 // Aumentado de 40 para 50
                                                : (isLargeScreen
                                                      ? 100
                                                      : 80), // Aumentado de 90/70 para 100/80
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.04),

                          // ✅ LEGENDA RESPONSIVA
                          Flexible(
                            // ✅ USA FLEXIBLE EM VEZ DE EXPANDED
                            child: Consumer<AppData>(
                              builder: (context, appData, child) {
                                final starRatings = appData.getTodayStarRatings(
                                  widget.currentShift,
                                );
                                final int count = starRatings[starValue] ?? 0;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      legendaAtual,
                                      style: TextStyle(
                                        fontSize: isSmallScreen
                                            ? 18
                                            : (isLargeScreen ? 32 : 24),
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                    Text(
                                      count == 1
                                          ? '($count avaliação hoje)'
                                          : '($count avaliações hoje)',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 16,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
