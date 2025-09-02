import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/profile_service.dart';
import '../services/srs_service.dart';

class TelaEstudo extends StatefulWidget {
  final Baralho baralho;
  final String userId;
  const TelaEstudo({super.key, required this.baralho, required this.userId});

  @override
  State<TelaEstudo> createState() => _TelaEstudoState();
}

class _TelaEstudoState extends State<TelaEstudo> {
  final ProfileService _profileService = ProfileService();
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<Cartao>> _cardsParaEstudarFuture;
  
  List<Cartao> _filaDeEstudo = [];
  List<Cartao> _filaDeLapsos = [];

  Map<int, String> _proximosIntervalos = {};

  int _cardAtualIndex = 0;
  bool _mostrandoVerso = false;
  bool _emRevisaoDeLapsos = false;
  bool _streakAlreadyUpdated = false;

  @override
  void initState() {
    super.initState();
    _carregarCards();
  }

  void _carregarCards() {
    _cardsParaEstudarFuture = _firestoreService
        .getCards(widget.userId, widget.baralho.id!)
        .first
        .then((todosOsCards) {
      final agora = DateTime.now();
      _filaDeEstudo = todosOsCards
          .where((card) =>
              card.proximaRevisao.isBefore(agora) || card.repeticoes == 0)
          .toList();
      _filaDeEstudo.shuffle();
      return _filaDeEstudo;
    });
  }

  void _processarResposta(int qualidade) async {
    if (_filaDeEstudo.isEmpty) return;

    if (!_streakAlreadyUpdated) {
      await _profileService.updateStudyStreak(widget.userId);
      setState(() { _streakAlreadyUpdated = true; });
    }
    await _profileService.addXp(widget.userId, 5);
    
    Cartao cardAtual = _filaDeEstudo[_cardAtualIndex];
    Cartao cardAtualizado = SrsService.calcular(cardAtual, qualidade);

    try {
      await _firestoreService.updateCard(
          widget.userId, widget.baralho.id!, cardAtualizado);
      
      if (qualidade < 3) {
        _filaDeLapsos.add(cardAtual);
      }
      _avancarCard();
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar o progresso: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _avancarCard() {
    setState(() {
      _mostrandoVerso = false;
      _proximosIntervalos.clear();

      if (_cardAtualIndex < _filaDeEstudo.length - 1) {
        _cardAtualIndex++;
      } else {
        if (_filaDeLapsos.isNotEmpty) {
          _emRevisaoDeLapsos = true;
          _filaDeEstudo = List.from(_filaDeLapsos);
          _filaDeLapsos.clear();
          _cardAtualIndex = 0;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Revisando os cartões que você errou..."), backgroundColor: Colors.orangeAccent),
          );
        } else {
          _filaDeEstudo = []; 
        }
      }
    });
  }

  void _calcularProximosIntervalos() {
    if (_filaDeEstudo.isEmpty) return;
    final card = _filaDeEstudo[_cardAtualIndex];
    
    final resultados = <int, String>{};
    for (var qualidade in [0, 3, 4, 5]) {
      final cartaoSimulado = Cartao.fromMap(card.toMap()); 
      final cartaoCalculado = SrsService.calcular(cartaoSimulado, qualidade);
      resultados[qualidade] = _formatarIntervalo(cartaoCalculado.intervalo);
    }

    setState(() {
      _proximosIntervalos = resultados;
    });
  }

  String _formatarIntervalo(int dias) {
    if (_emRevisaoDeLapsos || dias <= 1) return "< 10m"; // Se errou, revisa em breve
    if (dias < 30) return "${dias}d";
    if (dias < 365) return "${(dias / 30).toStringAsFixed(1)}m";
    return "${(dias / 365).toStringAsFixed(1)}a";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('studyingTitle'.tr(args: [widget.baralho.nome])),
      ),
      body: FutureBuilder<List<Cartao>>(
        future: _cardsParaEstudarFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar cartões: ${snapshot.error}"));
          }

          if (_filaDeEstudo.isEmpty) {
            return _buildTelaConclusao();
          }

          final cardAtual = _filaDeEstudo[_cardAtualIndex];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _emRevisaoDeLapsos 
                      ? "Revisão: ${ _cardAtualIndex + 1 } de ${ _filaDeEstudo.length }"
                      : "Restantes: ${ (_filaDeEstudo.length - _cardAtualIndex) + _filaDeLapsos.length }",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                flex: 3,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  color: Colors.blueGrey[800],
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Text(
                          _mostrandoVerso ? cardAtual.verso : cardAtual.frente,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _mostrandoVerso
                    ? _buildBotoesDeQualidade()
                    : _buildBotaoMostrarResposta(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBotaoMostrarResposta() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        ),
        onPressed: () {
          _calcularProximosIntervalos(); 
          setState(() => _mostrandoVerso = true);
        },
        child: const Text("Mostrar Resposta", style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildBotoesDeQualidade() {
    Widget buildButton(String label, int qualidade, Color color) {
      final intervalo = _proximosIntervalos[qualidade] ?? "";
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.all(12)),
        onPressed: () => _processarResposta(qualidade),
        child: Text("$label\n$intervalo", textAlign: TextAlign.center),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            buildButton("Errei", 0, Colors.redAccent),
            buildButton("Difícil", 3, Colors.orangeAccent),
            buildButton("Bom", 4, Colors.green),
            buildButton("Fácil", 5, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildTelaConclusao() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text(
            "Sessão Concluída!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Você revisou todos os cartões por hoje."),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Voltar para o baralho"),
          )
        ],
      ),
    );
  }
}
