// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

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
        theme: ThemeData(primarySwatch: Colors.red),
        home: const AppTabsController(),
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
  }

  // 2. MUDANÇA: Novo comportamento ao tocar nos itens da barra
  void _onItemTapped(int index) {
    // Se o usuário está voltando para a tela de Avaliação (índice 0)
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
    });
  }

  @override
  Widget build(BuildContext context) {
    // CORREÇÃO: Definição da lista DENTRO do método build, onde ela é usada.
    // MUDANÇA: Passa o 'currentShift' para as telas filhas.
    final List<Widget> widgetOptions = <Widget>[
      RatingSelectionScreen(
        onRatingSelected: _navigateToFeedbackScreen,
        selectedRating: _selectedRatingFromHome,
        currentShift: _currentShift,
      ), // // NOVO: Tela de emojis (NOVO ÍNDICE 0)
      RatingScreen(
        currentShift: _currentShift,
        initialRating: _selectedRatingFromHome ?? 0,
        initialTabIndex: _initialTabIndex ?? 0,
        onBackToHome: _resetHomeScreen, // ✅ ADICIONE ESTE PARÂMETRO
      ),
      StatisticsScreen(currentShift: _currentShift),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Avaliação do Restaurante (Turno $_currentShift)' // Exibe o turno no título
              : 'Estatísticas das Avaliações (Turno $_currentShift)',
          style: const TextStyle(
            fontSize: 24.0, // Aumentado para 24.0
            fontWeight: FontWeight.bold,
            color: Colors
                .white, // Garante que o texto fique branco contra o fundo escuro
          ),
        ),
        backgroundColor: Color.fromARGB(255, 111, 136, 63), //Colors.blueAccent
        elevation: 4,
        actions: _selectedIndex == 1
            ? [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions, color: Colors.white),
                  onPressed: () {
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
                  ), // Ícone do relógio/turno
                ),
              ],
      ),
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ), // Usa 'widgetOptions'
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // ... (Itens da barra de navegação)
          BottomNavigationBarItem(
            icon: Icon(
              Icons.insert_emoticon_rounded,
            ), // Ícone de casa ou outro de sua preferência
            label: 'Avaliações', // Rótulo da nova aba
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
        // ✅ NOVIDADE: Aumenta o tamanho da fonte para 16 (ou o valor desejado)
        selectedLabelStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14.0,
        ), // Opção: deixar a não selecionada um pouco menor
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green.shade700, //Colors.blueAccent
        onTap: _onItemTapped,
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
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
      length: 2,
      child: Stack(
        children: [
          // 1. IMAGEM DE FUNDO (Primeiro item da Stack)
          Positioned.fill(
            child: IgnorePointer(
              // Ignora o clique na imagem de fundo
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
                      width: 500,
                      height: 500,
                      child: Image.asset(
                        'assets/images/costa_feedbacks_logo.png',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. CONTEÚDO PRINCIPAL (Segundo item da Stack)
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DETALHES E ABAS: Aparecem SOMENTE após a seleção da estrela
                if (true) ...[
                  const Divider(height: 30),

                  // TAB BAR
                  Container(
                    color: Colors.transparent,
                    child: const TabBar(
                      labelColor: Color(0xFF3F4533), //Colors.blueAccent
                      unselectedLabelColor:
                          Colors.black54, //#3f4533, #e2e0d1, #39422f
                      indicatorColor: Color(0xFF3F4533), //Colors.blueAccent
                      // ✅ MUDANÇA AQUI: Aplicando o estilo ao texto das abas
                      labelStyle: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: [
                        Tab(text: 'Feedback Positivo'),
                        Tab(text: 'Feedback Negativo'),
                      ],
                    ),
                  ),

                  // TAB BAR VIEW (Conteúdo das abas)
                  Expanded(
                    child: TabBarView(
                      children: [
                        // CORRIGIDO: Agora usa a classe DetailedFeedbackTab
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

                  // NOVIDADE: CAMPO DE COMENTÁRIO
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 20.0,
                    ),
                    child: TextField(
                      controller: _commentController, // Usa o controller
                      maxLines: 3, // Permite 3 linhas de texto
                      decoration: const InputDecoration(
                        labelText: 'Escreva um comentário (Opcional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText:
                            'Digite aqui suas sugestões, elogios ou críticas...',
                      ),
                    ),
                  ),
                ] else
                  // Placeholder para empurrar o botão de envio
                  const Expanded(child: SizedBox.shrink()),

                // BOTÃO DE ENVIO: Aparece SOMENTE após a seleção da estrela
                if (true)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () => _sendRating(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 111, 136, 63),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Enviar Avaliação',
                        style: TextStyle(fontSize: 25, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
    final categories = ['Comida', 'Serviço', 'Ambiente'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: categories
                .map(
                  (c) => Expanded(
                    child: Center(
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0, // ✅ MUDANÇA APLICADA AQUI (18.0)
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categories
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
    // Definindo variáveis de cor e frase de forma CORRETA
    final bool isPositive = sentiment == 'Positiva';
    final Color baseColor = isPositive
        ? Colors.green
        : Colors.red; //Colors.blueAccent
    final List<String> currentPhrases = phrases['$category $sentiment'] ?? [];

    // Calcula a largura da tela para limitar o botão (Tablet)
    final screenWidth = MediaQuery.of(context).size.width;
    final maxButtonWidth = (screenWidth < 600) ? double.infinity : 200.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
                  onTap: () =>
                      onPhraseSelected(phrase), // Chama o handler do pai
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // MÉTODO: Cria a aparência do botão dinâmico (AGORA Stateless)
  Widget _buildButton({
    required String phrase,
    required Color baseColor,
    required BuildContext context,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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

    // ✅ NOVIDADE: LÓGICA DE QUEBRA DE LINHA CONTROLADA
    String formattedPhrase = phrase;
    int firstSpaceIndex = phrase.indexOf(' ');

    if (firstSpaceIndex != -1) {
      // Encontra o primeiro espaço e substitui por uma quebra de linha
      formattedPhrase =
          phrase.substring(0, firstSpaceIndex) +
          '\n' +
          phrase.substring(firstSpaceIndex + 1);
    }
    // FIM DA NOVIDADE

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      // MUDANÇA PRINCIPAL: Usamos um GestureDetector para capturar o toque
      child: GestureDetector(
        onTap: onTap, // Captura o clique
        // O Container é nosso novo "botão" visual
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // 1. FUNDO E BORDA
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor
                : unselectedColor, // Preenchimento 100%
            borderRadius: BorderRadius.circular(8), // Borda arredondada
            border: Border.all(
              color: isSelected
                  ? primaryBorderColor
                  : Colors.grey.shade400, // Borda cinza/colorida
              width: isSelected ? 2.0 : 1.0,
            ),
          ),

          // 2. CONTEÚDO (Texto)
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ), // Padding interno confortável

          child: Text(
            formattedPhrase, // ✅ UTILIZA A STRING FORMATADA AQUI
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19.0,
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

class StatisticsScreen extends StatelessWidget {
  final int currentShift;
  const StatisticsScreen({super.key, required this.currentShift});

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

  @override
  Widget build(BuildContext context) {
    final int selectedShift = currentShift; // Obtém o turno atual
    return Consumer<AppData>(
      builder: (context, appData, child) {
        // ✅ SUBSTITUA pelos métodos do dia atual:
        final starRatings = appData.getTodayStarRatings(selectedShift);
        final detailedRatings = appData.getTodayDetailedRatings(selectedShift);
        final totalRatings = appData.getTodayTotalStarRatings(selectedShift);

        final int totalDetailedFeedbacks = detailedRatings.values.fold(
          0,
          (sum, count) => sum + count,
        );

        // ✅ ADICIONE um indicador de que são dados do dia:
        final now = DateTime.now();
        final todayFormatted = '${now.day}/${now.month}/${now.year}';
        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(56.0), //distância da borda superior
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 1. TÍTULO CENTRALIZADO
                const Text(
                  'Distribuição de Reações (Hoje)',
                  style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                // ✅ ADICIONE a data atual:
                Text(
                  'Data: $todayFormatted - Total de Avaliações: $totalRatings',
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),
                // 2. GRÁFICO + LEGENDA (responsivo)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 500;

                    final pieChartWidget = totalRatings == 0
                        ? const Center(
                            child: Text(
                              'Nenhuma avaliação de estrela ainda.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : PieChart(
                            PieChartData(
                              // MUDANÇA: Passa os dados filtrados
                              sections: _buildStarSections(
                                appData,
                                starRatings, // Passa starRatings
                                totalRatings, // Passa totalRatings
                                isWide ? 217 : 200,
                              ),
                              sectionsSpace: isWide ? 4 : 0,
                              centerSpaceRadius: isWide ? 70 : 40,
                              borderData: FlBorderData(show: false),
                            ),
                          );

                    if (isWide) {
                      return Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 350,
                              height: 350,
                              child: pieChartWidget,
                            ),
                            const SizedBox(width: 50),
                            SizedBox(
                              width: 200,
                              // MUDANÇA: Passa os dados filtrados
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
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: pieChartWidget,
                          ),
                          const SizedBox(height: 16),
                          // MUDANÇA: Passa os dados filtrados
                          _buildStarLegend(appData, starRatings, totalRatings),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 70),
                const Divider(),

                // 3. DETALHES (Frequência)
                const Text(
                  'Frequência dos Detalhes',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
                // NOVIDADE: Subtítulo com a contagem total
                Text(
                  // MUDANÇA: Usa o total filtrado
                  'Total de Feedbacks: $totalDetailedFeedbacks',
                  style: TextStyle(fontSize: 19, color: Colors.grey[700]),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 15), // espaço entre título e lista
                // Lista de detalhes
                // MUDANÇA: Passa os dados filtrados
                _buildDetailedStats(detailedRatings),
              ],
            ),
          ),
        );
      },
    );
  }

  // Seções para o Gráfico de Pizza de Estrelas (MUDANÇA nos parâmetros)
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
            radius: chartSize * 0.45,
            title: '${percentage.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(
              fontSize: 14,
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

  // SUBSTITUA O MÉTODO _buildStarLegend INTEIRO
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

          // ✅ NOVIDADE: Pega o rótulo de sentimento (index 0 = 1 estrela)
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
                Text(
                  // ✅ NOVIDADE: Usa o RÓTULO e mostra a contagem
                  '$label: ${count}',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Lista de detalhes de avaliação (Positivo/Negativo) (MUDANÇA nos parâmetros)
  Widget _buildDetailedStats(Map<String, int> detailedRatings) {
    if (detailedRatings.isEmpty) {
      return const Center(
        child: Text('Nenhum detalhe de feedback registrado.'),
      );
    }

    // MUDANÇA: Usa detailedRatings diretamente
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
                  fontSize: 16.0, // ✅ MUDANÇA: Aumentado para 16.0
                ),
              ),
              Text(
                _getDetailCountText(entry.value),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ), // ✅ MUDANÇA: Aumentado para 16.0
              ),
            ],
          ),
        );
      },
    );
  }
}

// Mantenha esta cor institucional definida no topo do seu main.dart
const Color costaFoodsColor = Color(0xFF3F4533);

// NOVO WIDGET (Substitui HelloScreen): A tela inicial de seleção da nota
class RatingSelectionScreen extends StatefulWidget {
  final Function(int, int) onRatingSelected;
  final int? selectedRating;
  final int currentShift;

  const RatingSelectionScreen({
    super.key,
    required this.onRatingSelected, // ✅ ADICIONE
    this.selectedRating, // ✅ ADICIONE
    required this.currentShift,
  });

  @override
  State<RatingSelectionScreen> createState() => _RatingSelectionScreenState();
}

class _RatingSelectionScreenState extends State<RatingSelectionScreen> {
  int _selectedStars = 0; // Estado para armazenar a seleção

  // Mapeamento dos emojis
  final List<String> _ratingEmojis = const ['😠', '😟', '😐', '🙂', '😍'];

  void _handleEmojiClick(int star) {
    setState(() {
      _selectedStars = star;
    });

    // Determina a aba inicial baseada na avaliação
    final int initialTab = (star >= 4) ? 0 : 1;
    int targetTab;
    if (star >= 4) {
      targetTab = 0; // Aba "Feedback Positivo"
    } else {
      targetTab = 1; // Aba "Feedback Negativo"
    }
    // ✅ ADICIONE um pequeno delay para ver a animação:
    Future.delayed(const Duration(milliseconds: 300), () {
      // Determina a aba inicial baseada na avaliação
      final int initialTab = (star >= 4) ? 0 : 1;

      // Navega automaticamente para a tela de feedbacks
      widget.onRatingSelected(star, initialTab);
    });
  }

  // Função para navegar para a tela de detalhes após a seleção (será chamada no build)
  void _navigateToDetails(int starValue) {
    // 1. Determina a aba de detalhes correta
    final int initialTab = (starValue >= 4) ? 0 : 1;

    widget.onRatingSelected(_selectedStars, initialTab);
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ ATENÇÃO: Esta estrutura deve ser adaptada para ser a TELA DE AVALIAÇÃO DO ÍNDICE 0.

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lista vertical dos Emojis
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Qual sua experiência geral?',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
              ),
              // ✅ ADICIONE a data atual:
              Consumer<AppData>(
                builder: (context, appData, child) {
                  final now = DateTime.now();
                  final todayFormatted = '${now.day}/${now.month}/${now.year}';
                  return Text(
                    'Hoje: $todayFormatted',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  );
                },
              ),
              const SizedBox(height: 40),
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

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    width: 500,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Container para o emoji
                        Container(
                          width: 100,
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => _handleEmojiClick(starValue),
                            padding: const EdgeInsets.all(8.0),
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
                              elevation:
                                  WidgetStateProperty.resolveWith<double?>((
                                    Set<WidgetState> states,
                                  ) {
                                    return isSelected ? 8.0 : 0.0;
                                  }),
                              shadowColor: WidgetStateProperty.all(
                                Colors.black.withOpacity(0.3),
                              ),
                            ),
                            icon: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 1.0,
                                end: isSelected ? 1.2 : 1.0,
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
                                        style: const TextStyle(fontSize: 110),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                        const SizedBox(width: 70),
                        // Container para a legenda E contador
                        Container(
                          width: 200,
                          alignment: Alignment.centerLeft,
                          child: Consumer<AppData>(
                            builder: (context, appData, child) {
                              // ✅ SUBSTITUA pelo método do dia atual:
                              final starRatings = appData.getTodayStarRatings(
                                widget.currentShift,
                              );
                              final int count = starRatings[starValue] ?? 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    legendaAtual,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    count == 1
                                        ? '(${count} avaliação hoje)' // ✅ ADICIONE "hoje"
                                        : '(${count} avaliações hoje)',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
