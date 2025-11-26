// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'dart:async'; // Importação do Timer

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

import 'package:share_plus/share_plus.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/services.dart'; // PARA FilteringTextInputFormatter

import 'package:shared_preferences/shared_preferences.dart';

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

  // ✅ LISTA DE UNIDADES DA EMPRESA
  final List<String> companyUnits = [
    'Matriz',
    'Incubatório',
    'Fábrica de Ração',
    'Matrizeiro Esmeraldas',
    'Matrizeiro C. do Cajuru',
    'Armazém de Grãos',
  ];

  // ✅ LISTA DE TIPOS DE UNIFORME PARA MATRIZ
  final List<String> uniformTypes = [
    'Uniforme Branco',
    'Uniforme Colorido',
    'Administrativo',
  ];

  String? _selectedUnit; // Unidade selecionada
  String? _selectedUniformType; // Tipo de uniforme selecionado
  bool _showUnitSelection = false; // Controla se mostra o pop-up
  bool _showUniformSelection = false; // Controla se mostra seleção de uniforme

  // NOVIDADE: Lista para armazenar CADA avaliação como um registro de mapa
  List<Map<String, dynamic>> allEvaluationRecords = [];

  // Mapeamentos para cálculo em tempo real (retornados na Estatística)
  Map<int, Map<int, int>> shiftRatingsCount = {
    1: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    2: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  };
  Map<int, Map<String, int>> shiftDetailedRatings = {1: {}, 2: {}};

  // CORREÇÃO: Variável de Sentimento definida no topo (acessível por todos os métodos)
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

  // ✅ VARIÁVEIS PARA FILTRO DE DATA
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _showDateFilterDialog = false;

  // ✅ GETTERS PARA AS DATAS
  DateTime? get selectedStartDate => _selectedStartDate;
  DateTime? get selectedEndDate => _selectedEndDate;
  bool get showDateFilterDialog => _showDateFilterDialog;

  // ✅ MÉTODO PARA ABRIR O DIALOG DE FILTRO
  void showDateFilter() {
    _selectedStartDate = null;
    _selectedEndDate = null;
    _showDateFilterDialog = true;
    notifyListeners();
  }

  // ✅ MÉTODO PARA SELECIONAR DATA INICIAL
  void selectStartDate(DateTime date) {
    _selectedStartDate = date;
    notifyListeners();
  }

  // ✅ MÉTODO PARA SELECIONAR DATA FINAL
  void selectEndDate(DateTime date) {
    _selectedEndDate = date;
    notifyListeners();
  }

  // ✅ MÉTODO PARA DEBUG DOS REGISTROS
  void _debugRecords() {
    print('📊 TOTAL DE REGISTROS: ${allEvaluationRecords.length}');
    for (var record in allEvaluationRecords) {
      final recordDate = DateTime.parse(record['timestamp']);
      final recordDay = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
      );
      print('   📅 Record: ${record['timestamp']} -> $recordDay');
    }
  }

  // ✅ MÉTODO PARA CONFIRMAR O FILTRO
  void confirmDateFilter(BuildContext context) {
    if (_selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione ambas as datas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ CORREÇÃO: Remove qualquer informação de hora/minuto/segundo
    final startDay = DateTime(
      _selectedStartDate!.year,
      _selectedStartDate!.month,
      _selectedStartDate!.day,
    );
    final endDay = DateTime(
      _selectedEndDate!.year,
      _selectedEndDate!.month,
      _selectedEndDate!.day,
    );

    print('🔍 VALIDAÇÃO DO FILTRO:');
    print('   Start Day: $startDay');
    print('   End Day: $endDay');
    print('   End is before Start: ${endDay.isBefore(startDay)}');

    if (endDay.isBefore(startDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data final não pode ser anterior à data inicial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showDateFilterDialog = false;
    notifyListeners();

    // Mostra informações do filtro aplicado
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Filtrando de ${_formatDate(startDay)} até ${_formatDate(endDay)}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    _debugRecords();
    _exportWithDateFilter(context);
    // Exporta o CSV com o filtro aplicado
    _exportWithDateFilter(context);
  }

  // ✅ MÉTODO PARA CANCELAR O FILTRO
  void cancelDateFilter() {
    _selectedStartDate = null;
    _selectedEndDate = null;
    _showDateFilterDialog = false;
    notifyListeners();
  }

  // Construtor: Chama o método de carregamento ao inicializar
  AppData() {
    Future.microtask(() => _initializeApp());
  }

  // ✅ INICIALIZAÇÃO DO APP
  Future<void> _initializeApp() async {
    await loadDataFromCSV();
    await _checkFirstTimeOpen();
  }

  // ✅ VERIFICA SE É A PRIMEIRA VEZ QUE ABRE O APP
  // ✅ VERIFICA SE É A PRIMEIRA VEZ QUE ABRE O APP (ATUALIZADO)
  Future<void> _checkFirstTimeOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstTime = prefs.getBool('is_first_time') ?? true;

    if (isFirstTime) {
      // É a primeira vez - mostra seletor de unidade
      _showUnitSelection = true;
      notifyListeners();

      // Marca que não é mais a primeira vez
      await prefs.setBool('is_first_time', false);
    } else {
      // Não é a primeira vez - carrega unidade e uniforme salvos
      _selectedUnit = prefs.getString('selected_unit');
      _selectedUniformType = prefs.getString('selected_uniform_type');
      _showUnitSelection = false;
      _showUniformSelection = false;
    }
  }

  // ✅ SELECIONA UMA UNIDADE
  Future<void> selectUnit(String unit) async {
    _selectedUnit = unit;

    // ✅ SE A UNIDADE FOR "MATRIZ", MOSTRA SELEÇÃO DE UNIFORME
    if (unit == 'Matriz') {
      _showUnitSelection = false;
      _showUniformSelection = true;
    } else {
      // Para outras unidades, vai direto para o app
      _showUnitSelection = false;
      _showUniformSelection = false;

      // Salva a unidade selecionada
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_unit', unit);
    }

    notifyListeners();
  }

  // ✅ SELECIONA UM TIPO DE UNIFORME
  Future<void> selectUniformType(String uniformType) async {
    _selectedUniformType = uniformType;
    _showUniformSelection = false;

    // Salva as preferências
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_unit', 'Matriz');
    await prefs.setString('selected_uniform_type', uniformType);

    notifyListeners();
  }

  // ✅ GETTERS PARA ACESSAR OS DADOS
  String? get selectedUnit => _selectedUnit;
  String? get selectedUniformType => _selectedUniformType;
  bool get showUnitSelection => _showUnitSelection;
  bool get showUniformSelection => _showUniformSelection;

  // ✅ MÉTODO PARA OBTER O NOME COMPLETO DA UNIDADE
  String getFullUnitName() {
    if (_selectedUnit == 'Matriz' && _selectedUniformType != null) {
      return '$_selectedUnit - $_selectedUniformType';
    }
    return _selectedUnit ?? 'Não definida';
  }

  // ✅ MÉTODO PARA ALTERAR A UNIDADE (se necessário)
  Future<void> changeUnit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', true); // Reseta para mostrar seletor
    _showUnitSelection = true;
    _selectedUnit = null;
    notifyListeners();
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
    final String satisfacao = _getSatisfactionStatus(
      star,
    ); // ✅ CALCULA SATISFAÇÃO
    final String unidadeCSV = _getUnitForCSV(); // ✅ UNIDADE FORMATADA

    final newRecord = {
      'timestamp': DateTime.now().toIso8601String(),
      'turno': shift,
      'estrelas': star,
      'satisfacao': satisfacao, // ✅ ADICIONA SATISFAÇÃO
      'positivos': positiveFeedbacks.join('; '),
      'negativos': negativeFeedbacks.join('; '),
      'comentario': comment ?? '',
      'satisfacao': satisfacao,
      'unidade_csv': unidadeCSV,
    };

    allEvaluationRecords.add(newRecord);

    _recalculateCounts();
    notifyListeners();
    saveDataToCSV();
  }

  // CORRIGIDO: Método para classificar o feedback (usado no _sendRating)
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
      'satisfacao',
      'positivos_clicados',
      'negativos_clicados',
      'comentario',
      'unidade',
    ]);

    // Linhas de dados (Itera sobre a lista de registros)
    for (var record in allEvaluationRecords) {
      final int stars = record['estrelas'] as int;
      // ✅ CALCULA SATISFAÇÃO
      final String satisfacao = _getSatisfactionStatus(stars);
      csvData.add([
        record['timestamp'],
        record['turno'],
        record['estrelas'],
        satisfacao,
        record['positivos'],
        record['negativos'],
        record['comentario'],
        _getUnitForCSV(),
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

      if (row.length >= 7) {
        Map<String, dynamic> record = {
          'timestamp': row[0].toString(),
          'turno': row[1] as int,
          'estrelas': row[2] as int,
          'positivos': row[4].toString(),
          'negativos': row[5].toString(),
          'comentario': row[6].toString(),
        };

        // ✅ COLUNA DE SATISFAÇÃO (índice 3)
        if (row.length > 3) {
          record['satisfacao'] = row[3].toString();
        } else {
          final int stars = row[2] as int;
          record['satisfacao'] = _getSatisfactionStatus(stars);
        }

        // ✅ COLUNA DE UNIDADE (índice 7 - se existir)
        if (row.length >= 8) {
          record['unidade_csv'] = row[7].toString();
        }

        allEvaluationRecords.add(record);
      }
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

      // MUDE: Inclui de sevenDaysAgo até yesterday (exclui hoje)
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

    // CORREÇÃO: Preencher dias faltantes de ONTEM até 7 dias atrás
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

  // MÉTODO PARA CONVERTER NÚMERO PARA NOME DA CATEGORIA
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

  /// DIALOG DE SUCESSO COM OPÇÕES
  Future<void> _showExportSuccessDialog(
    BuildContext context,
    String filePath,
  ) async {
    if (!context.mounted) return;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: true,
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
        await Share.shareXFiles(
          [XFile(filePath)],
          text: _getShareMessage(), // ✅ MENSAGEM NO COMPARTILHAMENTO DIRETO
        );
        break;
      case 2: // Compartilhar
        await Share.shareXFiles(
          [XFile(filePath)],
          text: _getShareMessage(), // ✅ MENSAGEM NO COMPARTILHAMENTO
          subject: 'Avaliações Restaurante Costa Foods - Relatório',
        );
        break;
      // case 3: OK - não faz nada
    }
  }

  // MÉTODO ALTERNATivo - Salvar Diretamente na Pasta Downloads
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

  String? _lastSavedPath; // Guardar o último caminho salvo

  // MÉTODO PARA SALVAR EM PASTA VISÍVEL (CORRIGIDO)
  // ✅ MÉTODO PARA EXPORTAR COM FILTRO DE DATA
  Future<void> exportCSV(BuildContext context) async {
    try {
      // Mostra o dialog de seleção de datas primeiro
      _showDateFilterDialog = true;
      notifyListeners();
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

  // ✅ NOVO MÉTODO PARA EXPORTAR COM FILTRO APLICADO
  Future<void> _exportWithDateFilter(BuildContext context) async {
    try {
      final csvData = await _generateFilteredCSVContent();

      // ✅ USA UMA CLASSE COM TIMEOUT PARA O DIALOG
      await showDialog<int>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _ExportOptionsDialogWithTimeout(
          appData: this,
          csvData: csvData,
          startDate: _selectedStartDate!,
          endDate: _selectedEndDate!,
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

  // ✅ GERAR CONTEÚDO CSV FILTRADO POR DATA
  Future<String> _generateFilteredCSVContent() async {
    final List<List<dynamic>> csvData = [];

    csvData.add([
      'Unidade',
      'Data/Hora',
      'Turno',
      'Avaliação',
      'Categoria',
      'Status de Satisfação',
      'Feedbacks Positivos',
      'Feedbacks Negativos',
      'Comentário',
    ]);

    // ✅ DEBUG: Mostrar informações do filtro
    print('🎯 FILTRO APLICADO:');
    print('   Data Inicial: $_selectedStartDate');
    print('   Data Final: $_selectedEndDate');

    for (var record in allEvaluationRecords) {
      final recordDate = DateTime.parse(record['timestamp']);
      final recordDay = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
      );

      // ✅ APLICA FILTRO CORRETAMENTE
      if (_selectedStartDate != null && _selectedEndDate != null) {
        // Converte as datas selecionadas para o início do dia
        final startDay = DateTime(
          _selectedStartDate!.year,
          _selectedStartDate!.month,
          _selectedStartDate!.day,
        );
        final endDay = DateTime(
          _selectedEndDate!.year,
          _selectedEndDate!.month,
          _selectedEndDate!.day,
        );

        // ✅ VERIFICAÇÃO CORRETA: recordDay deve ser >= startDay E <= endDay
        final isAfterOrEqualStart =
            recordDay.isAfter(startDay) || _isSameDay(recordDay, startDay);
        final isBeforeOrEqualEnd =
            recordDay.isBefore(endDay) || _isSameDay(recordDay, endDay);

        final shouldInclude = isAfterOrEqualStart && isBeforeOrEqualEnd;

        // Debug para cada registro
        print(
          '   📅 Record: $recordDay | Start: $startDay | End: $endDay | Include: $shouldInclude',
        );

        if (!shouldInclude) {
          continue; // Pula registros fora do intervalo
        }
      }

      final int stars = record['estrelas'] as int;
      final category = getCategoryName(stars);
      final turno = record['turno'] == 1 ? 'Manhã/Tarde' : 'Noite/Madrugada';
      final String satisfactionStatus =
          record['satisfacao']?.toString() ?? _getSatisfactionStatus(stars);

      csvData.add([
        getFullUnitName(),
        record['timestamp'],
        turno,
        '${record['estrelas']} estrelas ($category)',
        category,
        satisfactionStatus,
        record['positivos'],
        record['negativos'],
        record['comentario'] ?? '',
      ]);
    }

    print('✅ Filtro finalizado: ${csvData.length - 1} registros incluídos');
    return const ListToCsvConverter().convert(csvData);
  }

  // ✅ MÉTODO AUXILIAR PARA COMPARAR SE É O MESMO DIA
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // ✅ FORMATAR DATA PARA EXIBIÇÃO
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // SALVAR DIRETO NO DISPOSITIVO
  String? _lastSavedFilePath; // Guarda o último caminho salvo

  // SALVAR NO DISPOSITIVO - MÉTODO CORRIGIDO
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

      print(' Arquivo salvo em: ${file.path}'); // Para debug
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

  // DIALOG DE SUCESSO COM BOTÃO "ABRIR PASTA"
  void _showSaveSuccessDialog(
    BuildContext context,
    String filePath,
    String fileName,
  ) {
    final directoryPath = File(filePath).parent.path;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivo Salvo!'),
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

  // ABRIR GERENCIADOR DE ARQUIVOS
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

  // FALLBACK PARA ABRIR GERENCIADOR
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

  // MOSTRAR CAMINHO COMPLETO
  void _showPathDialog(String path) {
    // Pode ser implementado se quiser mostrar um dialog com o caminho
    print('Caminho do arquivo: $path');
  }

  // CONVERTER CAMINHO PARA FORMATO ANDROID
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

  // ENCURTAR CAMINHO PARA EXIBIÇÃO
  String _getShortPath(String path) {
    if (path.length > 50) {
      return '...${path.substring(path.length - 47)}';
    }
    return path;
  }

  // OBTER PASTA DOWNLOADS PÚBLICA (Android 10+)
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

  // SALVAR NO DISPOSITIVO
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
            content: const Text('Arquivo salvo na pasta Downloads!'),
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

      print('✔️ Arquivo salvo em: ${file.path}');
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

  // SALVAR NA PASTA DE DOCUMENTOS (fallback)
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

  // DATA FORMATADA PARA O NOME DO ARQUIVO
  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  // ABRIR ARQUIVO - MÉTODO FUNCIONAL
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

  // ✅ COMPARTILHAR ARQUIVO COM MENSAGEM PERSONALIZADA
  Future<void> _shareFile(BuildContext context, String csvData) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/avaliacoes_costa_foods.csv');
      await file.writeAsString(csvData, flush: true);

      // ✅ MENSAGEM PERSONALIZADA PARA COMPARTILHAMENTO
      final String shareMessage = _getShareMessage();

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareMessage, // ✅ MENSAGEM PERSONALIZADA
        subject:
            '(${_selectedUnit ?? 'Não definida'}) Avaliações Restaurante Costa Foods - Relatório', // ✅ ASSUNTO
      );
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

  // ✅ GERA MENSAGEM PERSONALIZADA PARA COMPARTILHAMENTO
  String _getShareMessage() {
    final totalAvaliacoes = allEvaluationRecords.length;

    return '''
Unidade: ${_selectedUnit ?? 'Não definida'}
Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

Arquivo contém dados completos das avaliações dos clientes.
''';
  }

  // OBTER PASTA DOWNLOADS
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

  // ABRIR PASTA - MÉTODO FUNCIONAL
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

  // GERAR CONTEÚDO CSV (mantém igual)
  Future<String> _generateCSVContent() async {
    final List<List<dynamic>> csvData = [];

    csvData.add([
      'Unidade',
      'Data/Hora',
      'Turno',
      'Avaliação',
      'Categoria',
      'Status de Satisfação',
      'Feedbacks Positivos',
      'Feedbacks Negativos',
      'Comentário',
    ]);

    for (var record in allEvaluationRecords) {
      final int stars = record['estrelas'] as int;
      final category = getCategoryName(stars);
      final turno = record['turno'] == 1 ? 'Manhã/Tarde' : 'Noite/Madrugada';
      final String satisfactionStatus =
          record['satisfacao']?.toString() ?? _getSatisfactionStatus(stars);

      csvData.add([
        getFullUnitName(), // ✅ USA O NOME COMPLETO DA UNIDADE
        record['timestamp'],
        turno,
        '${record['estrelas']} estrelas ($category)',
        category,
        satisfactionStatus,
        record['positivos'],
        record['negativos'],
        record['comentario'] ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  // ✅ MÉTODO PARA DETERMINAR STATUS DE SATISFAÇÃO
  String _getSatisfactionStatus(int stars) {
    switch (stars) {
      case 5: // Excelente
      case 4: // Bom
        return 'Satisfeito';
      case 2: // Ruim
      case 1: // Péssimo
        return 'Insatisfeito';
      case 3: // Neutro
      default:
        return ''; // Vazio para neutro
    }
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

  // DIALOG DE SUCESSO COM AÇÕES FUNCIONAIS
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

  // ✅ MÉTODO PARA FORMATAR A UNIDADE NO CSV
  String _getUnitForCSV() {
    if (_selectedUnit == 'Matriz' && _selectedUniformType != null) {
      // ✅ PARA MATRIZ: MOSTRA APENAS A COR DO UNIFORME
      switch (_selectedUniformType) {
        case 'Uniforme Branco':
          return 'Branco';
        case 'Uniforme Colorido':
          return 'Colorido';
        case 'Administrativo':
          return 'Admin';
        default:
          return _selectedUniformType!;
      }
    }
    return _selectedUnit ?? 'Não definida';
  }
}

// ✅ CLASSE PARA DIALOG DE OPÇÕES DE EXPORTAÇÃO COM TIMEOUT
class _ExportOptionsDialogWithTimeout extends StatefulWidget {
  final AppData appData;
  final String csvData;
  final DateTime startDate;
  final DateTime endDate;

  const _ExportOptionsDialogWithTimeout({
    required this.appData,
    required this.csvData,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_ExportOptionsDialogWithTimeout> createState() =>
      _ExportOptionsDialogWithTimeoutState();
}

class _ExportOptionsDialogWithTimeoutState
    extends State<_ExportOptionsDialogWithTimeout> {
  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (mounted) {
        _closeDueToInactivity();
      }
    });
  }

  void _resetTimerOnInteraction() {
    _startInactivityTimer();
  }

  void _closeDueToInactivity() {
    if (mounted) {
      Navigator.of(context).pop(); // Fecha o dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exportação cancelada por inatividade'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleSaveToDevice() {
    _resetTimerOnInteraction();
    Navigator.of(context).pop(1);
    widget.appData._saveToDownloads(context, widget.csvData);
  }

  void _handleShare() {
    _resetTimerOnInteraction();
    Navigator.of(context).pop(2);
    widget.appData._shareFile(context, widget.csvData);
  }

  void _handleCancel() {
    _resetTimerOnInteraction();
    Navigator.of(context).pop(0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimerOnInteraction,
      onPanDown: (_) => _resetTimerOnInteraction(),
      behavior: HitTestBehavior.deferToChild,
      child: AlertDialog(
        title: const Text('Exportar Dados'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exportando dados de ${_formatDate(widget.startDate)} até ${_formatDate(widget.endDate)}',
            ),
            const SizedBox(height: 12),
            Text(
              'Esta tela fechará automaticamente em 20 segundos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _handleSaveToDevice,
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
            onPressed: _handleShare,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, color: Colors.green),
                SizedBox(width: 8),
                Text('Compartilhar'),
              ],
            ),
          ),
          TextButton(onPressed: _handleCancel, child: const Text('Cancelar')),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
          useMaterial3: true, // Design mais moderno e adaptável
        ),
        home:
            const AppWithUnitSelection(), // ✅ NOVO: Widget que gerencia o pop-up
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Força escala de texto responsiva
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

// ✅ NOVO WIDGET QUE GERENCIA O POP-UP DE UNIDADE
// ✅ NOVO WIDGET QUE GERENCIA O POP-UP DE UNIDADE E UNIFORME
class AppWithUnitSelection extends StatelessWidget {
  const AppWithUnitSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppData>(
      builder: (context, appData, child) {
        // ✅ SE PRECISA MOSTRAR O FILTRO DE DATAS
        if (appData.showDateFilterDialog) {
          return _buildDateFilterDialog(context, appData);
        }
        // ✅ SE PRECISA MOSTRAR A SELEÇÃO DE UNIFORME
        if (appData.showUniformSelection) {
          return _buildUniformSelectionDialog(context, appData);
        }

        // ✅ SE PRECISA MOSTRAR A SELEÇÃO DE UNIDADE
        if (appData.showUnitSelection) {
          return _buildUnitSelectionDialog(context, appData);
        }

        // ✅ SE JÁ TEM UNIDADE SELECIONADA, MOSTRA O APP NORMAL
        return const AppTabsController();
      },
    );
  }

  // ✅ MÉTODO PARA CONSTRUIR DIALOG DE SELEÇÃO DE UNIDADE
  Widget _buildUnitSelectionDialog(BuildContext context, AppData appData) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business_rounded,
                size: 64,
                color: const Color.fromARGB(255, 111, 136, 63),
              ),
              const SizedBox(height: 16),

              Text(
                'Bem-vindo ao Costa Foods Feedbacks!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 111, 136, 63),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Selecione a unidade onde serão feitas as avaliações:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              ...appData.companyUnits.map((unit) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => appData.selectUnit(unit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 111, 136, 63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),

              Text(
                'Esta seleção será salva e usada em todas as avaliações.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO PARA CONSTRUIR DIALOG DE SELEÇÃO DE UNIFORME
  Widget _buildUniformSelectionDialog(BuildContext context, AppData appData) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_alt_rounded,
                size: 64,
                color: const Color.fromARGB(255, 111, 136, 63),
              ),
              const SizedBox(height: 16),

              Text(
                'Seleção de Uniforme - Matriz',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 111, 136, 63),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Selecione o tipo de uniforme da equipe:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              ...appData.uniformTypes.map((uniformType) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => appData.selectUniformType(uniformType),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 111, 136, 63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      uniformType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: () {
                  // ✅ CORREÇÃO: Usa métodos públicos do AppData
                  appData._showUnitSelection = true;
                  appData._showUniformSelection = false;
                  appData.notifyListeners();
                },
                child: const Text('Voltar para seleção de unidade'),
              ),

              const SizedBox(height: 8),

              Text(
                'Esta seleção será salva e usada em todas as avaliações da Matriz.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ADICIONE ESTE MÉTODO NO AppWithUnitSelection
  Widget _buildDateFilterDialog(BuildContext context, AppData appData) {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365)); // 1 ano atrás
    final lastDate = now; // até hoje

    return _DateFilterDialogWithTimeout(
      appData: appData,
      now: now,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
}

// ✅ NOVA CLASSE PARA DIALOG DE DATA COM TIMEOUT
class _DateFilterDialogWithTimeout extends StatefulWidget {
  final AppData appData;
  final DateTime now;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateFilterDialogWithTimeout({
    required this.appData,
    required this.now,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateFilterDialogWithTimeout> createState() =>
      _DateFilterDialogWithTimeoutState();
}

class _DateFilterDialogWithTimeoutState
    extends State<_DateFilterDialogWithTimeout> {
  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (mounted) {
        _closeDueToInactivity();
      }
    });
  }

  void _resetTimerOnInteraction() {
    _startInactivityTimer();
  }

  void _closeDueToInactivity() {
    // Fecha o dialog de filtro de data
    widget.appData.cancelDateFilter();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleção de data cancelada por inatividade'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimerOnInteraction,
      onPanDown: (_) => _resetTimerOnInteraction(),
      behavior: HitTestBehavior.deferToChild,
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 64,
                  color: const Color.fromARGB(255, 111, 136, 63),
                ),
                const SizedBox(height: 16),

                Text(
                  'Filtrar por Data',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 111, 136, 63),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Selecione o período para exportar:',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // ✅ DATA INICIAL
                GestureDetector(
                  onTap: _resetTimerOnInteraction,
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.green,
                    ),
                    title: const Text('Data Inicial'),
                    subtitle: Text(
                      widget.appData.selectedStartDate != null
                          ? _formatDate(widget.appData.selectedStartDate!)
                          : 'Selecionar data',
                    ),
                    onTap: () async {
                      _resetTimerOnInteraction();
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            widget.appData.selectedStartDate ??
                            DateTime.now().subtract(const Duration(days: 7)),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (selectedDate != null) {
                        widget.appData.selectStartDate(selectedDate);
                        _resetTimerOnInteraction();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _resetTimerOnInteraction,
                  child: ListTile(
                    leading: const Icon(Icons.event, color: Colors.red),
                    title: const Text('Data Final'),
                    subtitle: Text(
                      widget.appData.selectedEndDate != null
                          ? _formatDate(widget.appData.selectedEndDate!)
                          : 'Selecionar data',
                    ),
                    onTap: () async {
                      _resetTimerOnInteraction();
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            widget.appData.selectedEndDate ?? DateTime.now(),
                        firstDate:
                            widget.appData.selectedStartDate ??
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (selectedDate != null) {
                        widget.appData.selectEndDate(selectedDate);
                        _resetTimerOnInteraction();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ BOTÕES DE AÇÃO
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _resetTimerOnInteraction();
                          widget.appData.cancelDateFilter();
                        },
                        child: OutlinedButton(
                          onPressed: () {
                            _resetTimerOnInteraction();
                            widget.appData.cancelDateFilter();
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _resetTimerOnInteraction,
                        child: ElevatedButton(
                          onPressed: () {
                            _resetTimerOnInteraction();
                            widget.appData.confirmDateFilter(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              111,
                              136,
                              63,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ),
                  ],
                ),

                // ✅ INDICADOR DE TIMEOUT
                const SizedBox(height: 16),
                Text(
                  'Esta tela fechará automaticamente em 20 segundos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO AUXILIAR PARA FORMATAR DATA
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ✅ CLASSE PARA DIALOG DE EXPORTAÇÃO COM TIMEOUT
class _ExportDialogWithTimeout extends StatefulWidget {
  final AppData appData;
  final String csvData;
  final DateTime startDate;
  final DateTime endDate;

  const _ExportDialogWithTimeout({
    required this.appData,
    required this.csvData,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_ExportDialogWithTimeout> createState() =>
      _ExportDialogWithTimeoutState();
}

class _ExportDialogWithTimeoutState extends State<_ExportDialogWithTimeout> {
  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (mounted) {
        _closeDueToInactivity();
      }
    });
  }

  void _resetTimerOnInteraction() {
    _startInactivityTimer();
  }

  void _closeDueToInactivity() {
    if (mounted) {
      Navigator.of(context).pop(); // Fecha o dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exportação cancelada por inatividade'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveToDownloads(BuildContext context) {
    _resetTimerOnInteraction();
    widget.appData._saveToDownloads(context, widget.csvData);
    Navigator.of(context).pop();
  }

  void _shareFile(BuildContext context) {
    _resetTimerOnInteraction();
    widget.appData._shareFile(context, widget.csvData);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimerOnInteraction,
      onPanDown: (_) => _resetTimerOnInteraction(),
      behavior: HitTestBehavior.deferToChild,
      child: AlertDialog(
        title: const Text('Exportar Dados'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exportando dados de ${_formatDate(widget.startDate)} até ${_formatDate(widget.endDate)}',
            ),
            const SizedBox(height: 16),
            Text(
              'Esta tela fechará automaticamente em 20 segundos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _resetTimerOnInteraction();
              _saveToDownloads(context);
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
              _resetTimerOnInteraction();
              _shareFile(context);
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
            onPressed: () {
              _resetTimerOnInteraction();
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

  // SENHA PARA ACESSAR ESTATÍSTICAS
  final String _statisticsPassword = "1234"; // Senha definida no código
  bool _showPasswordDialog = false;
  String _enteredPassword = "";

  // CONTROLLER PERMANENTE PARA O CAMPO DE SENHA
  final TextEditingController _passwordController = TextEditingController();

  // Timer para voltar à tela inicial após inatividade
  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(seconds: 20);

  // TIMER ESPECÍFICO PARA O TECLADO NUMÉRICO
  Timer? _keyboardInactivityTimer;
  final Duration _keyboardInactivityDuration = const Duration(seconds: 5);

  // ✅ NOVAS VARIÁVEIS PARA O POP-UP DE CONFIRMAÇÃO
  bool _showInactivityDialog = false;
  Timer? _countdownTimer;
  int _countdownSeconds = 10;
  final Duration _countdownDuration = const Duration(seconds: 10);

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
    _startInactivityTimer(); // INICIA O TIMER
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _keyboardInactivityTimer?.cancel();
    _passwordController.dispose(); // DISPOSE DO CONTROLLER
    _countdownTimer?.cancel(); // ✅ CANCELA TIMER DO CONTADOR
    super.dispose();
  }

  // INICIA O TIMER DE INATIVIDADE
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      // ✅ SE ESTÁ NA TELA DE FEEDBACKS OU ESTATÍSTICAS, MOSTRA POP-UP
      if ((_selectedIndex == 1 || _selectedIndex == 2) && mounted) {
        _showInactivityConfirmation();
      } else if (_selectedIndex != 0 && mounted) {
        // Para outras telas (se houver), volta diretamente
        _resetToHomeScreen();
      }
    });
  }

  // ✅ MOSTRA O POP-UP DE CONFIRMAÇÃO DE INATIVIDADE
  void _showInactivityConfirmation() {
    setState(() {
      _showInactivityDialog = true;
      _countdownSeconds = 10;
    });

    // ✅ INICIA O CONTADOR REGRESSIVO
    _startCountdownTimer();
  }

  // ✅ INICIA O CONTADOR REGRESSIVO
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0 && mounted) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        // ✅ TEMPO ESGOTADO - VOLTA PARA TELA INICIAL
        timer.cancel();
        _closeInactivityDialogAndReturnHome();
      }
    });
  }

  // ✅ USUÁRIO QUER PERMANECER
  void _stayOnCurrentScreen() {
    _closeInactivityDialog();
    _resetTimerOnInteraction(); // Reinicia o timer principal
  }

  // ✅ USUÁRIO QUER VOLTAR (OU TEMPO ESGOTOU)
  void _closeInactivityDialogAndReturnHome() {
    _closeInactivityDialog();
    _resetToHomeScreen();
  }

  // ✅ FECHA O DIALOG
  void _closeInactivityDialog() {
    _countdownTimer?.cancel();
    setState(() {
      _showInactivityDialog = false;
      _countdownSeconds = 10;
    });
  }

  // VOLTA PARA TELA INICIAL (COM FECHAMENTO DE DIALOGS)
  void _resetToHomeScreen() {
    _closeInactivityDialog(); // ✅ FECHA O DIALOG SE ESTIVER ABERTO
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).clearSnackBars();

    // CANCELA TIMERS
    // _keyboardInactivityTimer?.cancel();

    // // LIMPA CONTROLLER DE SENHA
    // _passwordController.clear();

    // ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      _selectedIndex = 0;
      _currentShift = _calculateDefaultShift();
      _selectedRatingFromHome = null;
      _initialTabIndex = null;
    });

    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text('Voltando para tela inicial por inatividade'),
    //     duration: Duration(seconds: 2),
    //   ),
    // );
  }

  // MÈTODO PÚBLICO
  void resetTimerOnInteraction() {
    _resetTimerOnInteraction();
  }

  // MÉTODO PRIVADO TAMBÉM
  void _resetTimerOnInteraction() {
    // ✅ SE HÁ DIALOG DE INATIVIDADE ABERTO, FECHA E REINICIA
    if (_showInactivityDialog) {
      _closeInactivityDialog();
    }

    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  // MOSTRA O DIALOG DE SENHA COM TECLADO NATIVO
  void _showPasswordInput() {
    _passwordController.clear(); // LIMPA O CAMPO

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPasswordDialog(),
    ).then((_) {
      _keyboardInactivityTimer?.cancel(); // CANCELA TIMER AO FECHAR
    });

    // INICIA O TIMER APÓS ABRIR O DIALOG
    _startKeyboardInactivityTimer();
  }

  // INICIA O TIMER DE INATIVIDADE DO TECLADO
  void _startKeyboardInactivityTimer() {
    _keyboardInactivityTimer?.cancel();
    _keyboardInactivityTimer = Timer(_keyboardInactivityDuration, () {
      if (mounted) {
        _closeKeyboardDueToInactivity();
      }
    });
  }

  // FECHA O TECLADO POR INATIVIDADE
  void _closeKeyboardDueToInactivity() {
    // VERIFICA SE O DIALOG AINDA ESTÁ ABERTO
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // FECHA O DIALOG
      _passwordController.clear(); // LIMPA A SENHA

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acesso às estatísticas cancelado por inatividade'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // REINICIA O TIMER DO TECLADO A CADA INTERAÇÃO
  void _resetKeyboardTimer() {
    _keyboardInactivityTimer?.cancel();
    _startKeyboardInactivityTimer();
  }

  // VERIFICA A SENHA (ATUALIZADO)
  void _checkPassword() {
    _keyboardInactivityTimer?.cancel(); // CANCELA TIMER

    final enteredPassword = _passwordController.text;

    if (enteredPassword == _statisticsPassword) {
      // Senha correta - permite acesso às estatísticas
      Navigator.of(context).pop(); // FECHA O DIALOG PRIMEIRO
      setState(() {
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
      _passwordController.clear(); // LIMPA O CAMPO
      _startKeyboardInactivityTimer(); // REINICIA TIMER APÓS ERRO
    }
  }

  // CANCELA O DIGITAR DA SENHA
  void _cancelPassword() {
    _keyboardInactivityTimer?.cancel(); // CANCELA TIMER DO TECLADO
    setState(() {
      _showPasswordDialog = false;
      _enteredPassword = "";
    });
  }

  // 2. MUDANÇA: Novo comportamento ao tocar nos itens da barra
  void _onItemTapped(int index) {
    _resetTimerOnInteraction(); // REINICIA TIMER
    // Se o usuário está voltando para a tela de Avaliação (índice 0)
    // VERIFICA SE É A ABA DE ESTATÍSTICAS (índice 2)
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

  void _navigateToFeedbackScreen(int rating, int tabIndex) {
    // REINICIA O TIMER AO ENTRAR NA TELA DE FEEDBACKS
    _resetTimerOnInteraction();

    // ADICIONE uma animação suave:
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

  // DIALOG SIMPLES COM TECLADO NATIVO
  Widget _buildPasswordDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return GestureDetector(
          onTap: () {
            _resetKeyboardTimer(); // REINICIA TIMER AO TOCAR NO DIALOG
          },
          child: AlertDialog(
            title: const Text(
              'Senha de Acesso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 111, 136, 63),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digite a senha para acessar as estatísticas:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),

                // CAMPO DE TEXTO COM TECLADO NUMÉRICO NATIVO
                GestureDetector(
                  onTap:
                      _resetKeyboardTimer, // REINICIA TIMER AO TOCAR NO CAMPO
                  child: TextFormField(
                    controller: _passwordController,
                    onChanged: (value) {
                      _resetKeyboardTimer(); // REINICIA TIMER A CADA DIGITAÇÃO

                      // ✅ CONFIRMAÇÃO AUTOMÁTICA AO DIGITAR O 4º DÍGITO
                      if (value.length == 4) {
                        Future.delayed(Duration(milliseconds: 100), () {
                          _checkPassword();
                        });
                      }

                      setDialogState(() {});
                    },
                    onTap:
                        _resetKeyboardTimer, // REINICIA TIMER AO FOCAR NO CAMPO
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, letterSpacing: 10),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    autofocus: true,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            actions: [
              // BOTÃO CANCELAR
              TextButton(
                onPressed: () {
                  _keyboardInactivityTimer?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ CONSTRÓI O DIALOG DE CONFIRMAÇÃO DE INATIVIDADE
  Widget _buildInactivityConfirmationDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ ÍCONE DE ALERTA
              Icon(
                Icons.timer_outlined,
                size: 64,
                color: Colors.orange.shade700,
              ),
              const SizedBox(height: 16),

              // ✅ TÍTULO
              Text(
                'Tempo de Inatividade',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // ✅ MENSAGEM
              Text(
                'Você está há algum tempo sem interagir. Deseja continuar na tela de feedbacks?',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // ✅ CONTADOR REGRESSIVO
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Voltando em $_countdownSeconds segundos...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _countdownSeconds <= 5
                        ? Colors.red
                        : Colors.orange.shade700,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ✅ BOTÕES DE AÇÃO
              Row(
                children: [
                  // ✅ BOTÃO "NÃO" (VOLTAR)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closeInactivityDialogAndReturnHome,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Não, Voltar',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ✅ BOTÃO "SIM" (PERMANECER)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _stayOnCurrentScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          111,
                          136,
                          63,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Sim, Permanecer',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ✅ INFORMAÇÃO
              Text(
                'Se não responder, voltaremos automaticamente.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      RatingSelectionScreen(
        onRatingSelected: _navigateToFeedbackScreen,
        selectedRating: _selectedRatingFromHome,
        currentShift: _currentShift,
      ),
      RatingScreen(
        currentShift: _currentShift,
        initialRating: _selectedRatingFromHome ?? 0,
        initialTabIndex: _initialTabIndex ?? 0,
        onBackToHome: _resetHomeScreen,
      ),
      StatisticsScreen(currentShift: _currentShift),
    ];

    return Consumer<AppData>(
      builder: (context, appData, child) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedIndex == 0
                      ? 'Avaliação do Restaurante (Turno $_currentShift)'
                      : 'Feedbacks (Turno $_currentShift)',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (appData.selectedUnit != null)
                  Text(
                    appData.selectedUnit!,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white70,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
            backgroundColor: Color.fromARGB(255, 111, 136, 63),
            elevation: 4,
            actions: _selectedIndex == 1 ? [] : [],
          ),
          body: Stack(
            children: [
              // ✅ GESTUREDETECTOR QUE NÃO BLOQUEIA OS CLIQUES
              GestureDetector(
                onTap: _resetTimerOnInteraction,
                onPanDown: (_) => _resetTimerOnInteraction(),
                onScaleStart: (_) => _resetTimerOnInteraction(),
                behavior: HitTestBehavior
                    .deferToChild, // ✅ PERMITE CLIQUES NOS FILHOS
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(child: widgetOptions.elementAt(_selectedIndex)),
                ),
              ),

              // DIALOG DE SENHA (se necessário)
              if (_showPasswordDialog) _buildPasswordDialog(),

              // ✅ NOVO: DIALOG DE INATIVIDADE (apenas na tela de feedbacks)
              if (_showInactivityDialog &&
                  (_selectedIndex == 1 || _selectedIndex == 2))
                _buildInactivityConfirmationDialog(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
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
            onTap: (index) {
              _resetTimerOnInteraction();
              _onItemTapped(index);
            },
          ),
        );
      },
    );
  }
}
// ===================================================================
// TELA 1: AVALIAÇÃO (COM IMAGEM DE FUNDO E FLUXO CONDICIONAL)
// ===================================================================

class RatingScreen extends StatefulWidget {
  // ADICIONADO: Recebe a nota inicial e o índice da aba
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

    // INICIA O TIMER QUANDO A TELA DE FEEDBACKS É ABERTA
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appTabsControllerState = context
          .findAncestorStateOfType<_AppTabsControllerState>();
      appTabsControllerState?._resetTimerOnInteraction();
    });

    // CORREÇÃO: Inicializa com o valor passado ou usa 0 como padrão.
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
      // CORREÇÃO: Apenas a estrela clicada é armazenada (comportamento "radio button")
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

  // ✅ MÉTODO PARA REINICIAR TIMER DO PARENT
  void _resetParentTimer(BuildContext context) {
    final appTabsControllerState = context
        .findAncestorStateOfType<_AppTabsControllerState>();
    appTabsControllerState?._resetTimerOnInteraction();
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
            // FUNDO RESPONSIVO
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
                          'assets/images/costa_foods_feedbacks.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // CONTEÚDO RESPONSIVO
            Column(
              children: [
                // TAB BAR RESPONSIVO
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

                // COMENTÁRIO RESPONSIVO
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
                    onChanged: (value) {
                      // ✅ REINICIA TIMER A CADA CARACTERE DIGITADO
                      _resetParentTimer(context);
                    },
                  ),
                ),

                // BOTÃO RESPONSIVO
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
          // CATEGORIAS RESPONSIVAS
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

          // BOTÕES RESPONSIVOS
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

    // DETECÇÃO DE TAMANHO DE TELA
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    // LARGURA MÁXIMA RESPONSIVA
    final maxButtonWidth = isSmallScreen
        ? screenWidth * 0.9
        : (isLargeScreen ? 200.0 : double.infinity);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
      ), // PADDING RESPONSIVO
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

  // ✅ MÉTODO PARA REINICIAR TIMER
  void _resetParentTimer(BuildContext context) {
    final appTabsControllerState = context
        .findAncestorStateOfType<_AppTabsControllerState>();
    appTabsControllerState?._resetTimerOnInteraction();
  }

  // MÉTODO _buildButton RESPONSIVO
  Widget _buildButton({
    required String phrase,
    required Color baseColor,
    required BuildContext context,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // DETECÇÃO DE TAMANHO
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

    // QUEBRA DE LINHA RESPONSIVA
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
      ), // ESPAÇAMENTO RESPONSIVO
      child: GestureDetector(
        onTap: () {
          _resetParentTimer(context); // ✅ REINICIA TIMER
          onTap();
        },
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
          // PADDING RESPONSIVO
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03,
            vertical: isSmallScreen ? 8 : (isLargeScreen ? 12 : 10),
          ),
          alignment: Alignment.center,
          child: Text(
            formattedPhrase,
            textAlign: TextAlign.center,
            // TEXTO RESPONSIVO
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
  // ADICIONE: Estado para controlar o tipo de gráfico
  String _selectedView = 'Total'; // 'Total', 'Média', 'MaisAvaliado'

  // LEGENDAS NA ORDEM CORRETA: Excelente → Péssimo
  static List<String> _sentimentLabels = [
    'Excelente', // Índice 0 - 5 estrelas
    'Bom', // Índice 1 - 4 estrelas
    'Neutro', // Índice 2 - 3 estrelas
    'Ruim', // Índice 3 - 2 estrelas
    'Péssimo', // Índice 4 - 1 estrela
  ];

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

  // FECHA TODOS OS OVERLAYS/POP-UPS
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

  // ✅ MÉTODO PARA REINICIAR TIMER
  // ✅ MÉTODO PARA REINICIAR TIMER
  void _resetTimer() {
    final appTabsControllerState = context
        .findAncestorStateOfType<_AppTabsControllerState>();
    appTabsControllerState?._resetTimerOnInteraction();
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

  // MÉTODO PARA CONVERTER NÚMERO PARA NOME DA CATEGORIA
  String getCategoryName(int stars) {
    switch (stars) {
      case 5:
        return 'Excelente'; // AGORA NO TOPO
      case 4:
        return 'Bom';
      case 3:
        return 'Neutro';
      case 2:
        return 'Ruim';
      case 1:
        return 'Péssimo'; // AGORA NA BASE
      default:
        return '$stars estrelas';
    }
  }

  // ADICIONE os botões de controle
  Widget _buildViewSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      children: [
        if (isSmallScreen) // LAYOUT VERTICAL PARA TELAS PEQUENAS
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
        else // LAYOUT HORIZONTAL PARA TELAS MÉDIAS/GRANDES
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

    // DETECÇÃO DE TAMANHO
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
                    // PADDING RESPONSIVO
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

                        // MAIS ESPAÇO ENTRE TÍTULO E SUBTÍTULO
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

                        // MAIS ESPAÇO ENTRE SUBTÍTULO E GRÁFICO
                        SizedBox(height: isSmallScreen ? 28 : 50),

                        // 2. GRÁFICO + LEGENDA
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 500;

                            // TAMANHO DO GRÁFICO FIXO PARA GARANTIR VISIBILIDADE
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

                                  // MAIS ESPAÇO ENTRE GRÁFICO E LEGENDA
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

                        // MAIS ESPAÇO ENTRE GRÁFICO E DIVIDER
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

                        // ESPAÇO ENTRE TÍTULO E SUBTÍTULO DOS DETALHES
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

                        // ESPAÇO ENTRE SUBTÍTULO E LISTA
                        SizedBox(height: isSmallScreen ? 16 : 20),

                        _buildDetailedStats(detailedRatings),

                        // BOTÕES E GRÁFICOS CONDICIONAIS RESPONSIVOS
                        SizedBox(height: isSmallScreen ? 30 : 45),

                        const Divider(),

                        // ESPAÇO ENTRE DIVIDER E TÍTULO
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

                        // ESPAÇO ENTRE TÍTULO E BOTÕES
                        SizedBox(height: isSmallScreen ? 18 : 24),

                        _buildViewSelector(),

                        // ESPAÇO ENTRE BOTÕES E GRÁFICOS
                        SizedBox(height: isSmallScreen ? 20 : 28),

                        // GRÁFICOS CONDICIONAIS
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
              // BOTÃO DE EXPORTAÇÃO
              _buildExportButton(context),
            ],
          ),
        );
      },
    );
  }

  // MODIFIQUE O MÉTODO _buildExportButton para usar Navigator
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
        onPressed: () {
          _resetTimer(); // ✅ REINICIA TIMER
          _exportDataWithSafety(context);
        },
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

  // NOVO MÉTODO SEGURO PARA EXPORTAÇÃO
  void _exportDataWithSafety(BuildContext context) {
    // Fecha qualquer pop-up existente antes de abrir novo
    Navigator.of(context).popUntil((route) => route.isFirst);

    final appData = Provider.of<AppData>(context, listen: false);
    appData.exportCSV(
      context,
    ); // ✅ AGORA ISSO ABRIRÁ O FILTRO DE DATAS PRIMEIRO
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

  // MOSTRAR OPÇÕES DE EXPORTAÇÃO
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
            radius: chartSize * 0.4, // RAIO PROPORCIONAL
            title: '${percentage.toStringAsFixed(0)}%',
            titleStyle: TextStyle(
              fontSize: chartSize * 0.06, // TEXTO RESPONSIVO
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        })
        .whereType<PieChartSectionData>()
        .toList();
  }

  Widget _buildStarLegend(
    AppData appData,
    Map<int, int> starRatings,
    int totalRatings,
  ) {
    // ✅ LISTA DE LABELS NA ORDEM CORRETA: Excelente -> Péssimo
    final List<String> sentimentLabels = [
      'Excelente',
      'Bom',
      'Neutro',
      'Ruim',
      'Péssimo',
    ];

    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ PERCORRE NA ORDEM INVERSA: 5, 4, 3, 2, 1
          for (int star = 5; star >= 1; star--)
            if (starRatings[star] != null && starRatings[star]! > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      color: appData
                          .pieColors[star - 1], // ✅ CORES MANTIDAS CORRETAS
                      margin: const EdgeInsets.only(right: 20),
                    ),
                    Text(
                      '${sentimentLabels[5 - star]}: ${starRatings[star]}', // ✅ NOME CORRETO
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
        ],
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

  // GRÁFICO DE TOTAL
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

  // GRÁFICO DE MÉDIA
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

  // GRÁFICO DO MAIS AVALIADO
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
            _buildLegendItem(Colors.green.shade700, 'Excelente'), // 5 ESTRELAS
            _buildLegendItem(Colors.lightGreen, 'Bom'), // 4 ESTRELAS
            _buildLegendItem(Colors.amber, 'Neutro'), // 3 ESTRELAS
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.deepOrange, 'Ruim'), // 2 ESTRELAS
            _buildLegendItem(Colors.red.shade700, 'Péssimo'), // 1 ESTRELA
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

  // EMOJIS NA ORDEM CORRETA PARA A NOVA SEQUÊNCIA
  final List<String> _ratingImagePaths = [
    'assets/images/love.png', // 😍
    'assets/images/happy.png', // 🙂
    'assets/images/neutral.png', // 😐
    'assets/images/sad.png', // 😟
    'assets/images/angry.png', // 😠
  ];

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
        // IMAGEM DE FUNDO RESPONSIVA
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
                      'assets/images/costa_foods_feedbacks.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // CONTEÚDO PRINCIPAL RESPONSIVO - AGORA CORRETAMENTE CENTRALIZADO
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
                  // TÍTULO RESPONSIVO
                  Text(
                    'Qual sua experiência geral?',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 28 : (isLargeScreen ? 44 : 36),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // DATA RESPONSIVA
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

                  SizedBox(
                    height:
                        screenHeight *
                        0.01, //alterar distância entre data e emojis
                  ),
                  // EMOJIS NA ORDEM INVERTIDA: EXCELENTE (5) → PÉSSIMO (1)
                  ...List.generate(5, (index) {
                    // INVERTE A ORDEM: 5,4,3,2,1 em vez de 1,2,3,4,5
                    final int starValue =
                        5 -
                        index; // Excelente=5, Bom=4, Neutro=3, Ruim=2, Péssimo=1
                    final String currentEmoji =
                        _ratingImagePaths[index]; // USA O ÍNDICE DIRETO
                    final bool isSelected = starValue == _selectedStars;

                    final List<String> legendas = [
                      'Excelente', // AGORA NA POSIÇÃO 0 (primeiro)
                      'Bom', // POSIÇÃO 1
                      'Neutro', // POSIÇÃO 2
                      'Ruim', // POSIÇÃO 3
                      'Péssimo', // POSIÇÃO 4 (último)
                    ];
                    final String legendaAtual = legendas[index];

                    return Container(
                      width: screenWidth * 0.9,
                      margin: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ CONTAINER DA IMAGEM (USA starValue CORRETA)
                          Container(
                            width: screenWidth * 0.2,
                            child: IconButton(
                              onPressed: () => _handleEmojiClick(starValue),
                              padding: EdgeInsets.zero,
                              style: ButtonStyle(
                                side: WidgetStateProperty.all(BorderSide.none),
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color?>((
                                      states,
                                    ) {
                                      return isSelected
                                          ? Colors.amber.withOpacity(0.2)
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
                                  end: isSelected ? 1.3 : 1.0,
                                ),
                                duration: const Duration(milliseconds: 300),
                                builder:
                                    (
                                      BuildContext context,
                                      double scale,
                                      Widget? child,
                                    ) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.amber
                                                        .withOpacity(0.4),
                                                    blurRadius: 15,
                                                    spreadRadius: 3,
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                        ),
                                        child: Transform.scale(
                                          scale: scale,
                                          child: Image.asset(
                                            _ratingImagePaths[index], // ✅ USA index DIRETO (0-4)
                                            width: isSmallScreen
                                                ? 60
                                                : (isLargeScreen ? 120 : 90),
                                            height: isSmallScreen
                                                ? 60
                                                : (isLargeScreen ? 120 : 90),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.04),

                          // ✅ LEGENDA (USA starValue CORRETA PARA BUSCAR CONTAGEM)
                          Flexible(
                            child: Consumer<AppData>(
                              builder: (context, appData, child) {
                                final starRatings = appData.getTodayStarRatings(
                                  widget.currentShift,
                                );
                                final int count =
                                    starRatings[starValue] ??
                                    0; // ✅ USA starValue CORRETA

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
