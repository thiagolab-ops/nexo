import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/services/srs_service.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

class TelaEstudo extends StatefulWidget {
  final Baralho baralho;
  final String userId;
  const TelaEstudo({super.key, required this.baralho, required this.userId});

  @override
  State<TelaEstudo> createState() => _TelaEstudoState();
}

class _TelaEstudoState extends State<TelaEstudo> {
  late final ProfileService _profileService;
  late final FirestoreService _firestoreService;

  List<Cartao> _filaDeEstudo = [];
  Map<int, String> _proximosIntervalos = {};
  bool _isLoading = true;
  bool _mostrandoVerso = false;
  bool _streakAlreadyUpdated = false;

  @override
  void initState() {
    super.initState();
    _profileService = context.read<ProfileService>();
    _firestoreService = context.read<FirestoreService>();
    _carregarCards();
  }

  Future<void> _carregarCards() async {
    final todosOsCards = await _firestoreService.getCards(widget.userId, widget.baralho.id).first;
    final agora = DateTime.now();
    
    setState(() {
      _filaDeEstudo = todosOsCards.where((card) => card.proximaRevisao.isBefore(agora)).toList();
      _filaDeEstudo.shuffle();
      _isLoading = false;
    });
  }

  void _processarResposta(int qualidade) async {
    if (_filaDeEstudo.isEmpty) return;

    if (!_streakAlreadyUpdated) {
      await _profileService.updateStudyStreak(widget.userId);
      setState(() { _streakAlreadyUpdated = true; });
    }
    await _profileService.addXp(widget.userId, 5);

    Cartao cardAtual = _filaDeEstudo.first;

    if (qualidade < 3) {
      cardAtual.repeticoes = 0;
      
      final novaFila = List<Cartao>.from(_filaDeEstudo.sublist(1));
      novaFila.add(cardAtual);

      setState(() {
        _filaDeEstudo = novaFila;
        _mostrandoVerso = false;
        _proximosIntervalos.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Este cartão voltará em alguns minutos..."), backgroundColor: Colors.orangeAccent, duration: Duration(seconds: 2)),
      );
    } else {
      Cartao cardAtualizado = SrsService.calcular(cardAtual, qualidade);
      try {
        await _firestoreService.updateCard(widget.userId, widget.baralho.id, cardAtualizado);
        
        setState(() {
          _filaDeEstudo = _filaDeEstudo.sublist(1);
          _mostrandoVerso = false;
          _proximosIntervalos.clear();
        });
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao salvar o progresso: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _calcularProximosIntervalos() {
    if (_filaDeEstudo.isEmpty) return;
    final card = _filaDeEstudo.first;
    
    final resultados = <int, String>{};
    for (var qualidade in [0, 3, 4, 5]) {
      final cartaoSimulado = Cartao.fromMap(card.toMap());
      
      if (qualidade < 3) {
        resultados[qualidade] = "< 10m";
      } else {
        final cartaoCalculado = SrsService.calcular(cartaoSimulado, qualidade);
        resultados[qualidade] = _formatarIntervalo(cartaoCalculado.intervalo);
      }
    }

    setState(() {
      _proximosIntervalos = resultados;
    });
  }

  String _formatarIntervalo(int dias) {
    if (dias <= 1) return "1d";
    if (dias < 30) return "${dias}d";
    if (dias < 365) return "${(dias / 30).round()}m";
    return "${(dias / 365).toStringAsFixed(1)}a";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estudando: ${widget.baralho.nome}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filaDeEstudo.isEmpty
              ? _buildTelaConclusao()
              : _buildInterfaceEstudo(),
    );
  }

  Widget _buildInterfaceEstudo() {
    final cardAtual = _filaDeEstudo.first;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Restantes nesta sessão: ${_filaDeEstudo.length}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () {
              if (!_mostrandoVerso) {
                _calcularProximosIntervalos();
                setState(() => _mostrandoVerso = true);
              }
            },
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Text(
                      _mostrandoVerso ? cardAtual.verso : cardAtual.frente,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // --- PAINEL DE DEPURAÇÃO TEMPORÁRIO ---
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "DEBUG -> Repetições: ${cardAtual.repeticoes} | Intervalo: ${cardAtual.intervalo} | EF: ${cardAtual.easeFactor.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.yellow, fontSize: 12),
            ),
          ),
        // --- FIM DO PAINEL DE DEPURAÇÃO ---

        Expanded(
          flex: 2,
          child: _mostrandoVerso
              ? _buildBotoesDeQualidade()
              : _buildBotaoMostrarResposta(),
        ),
      ],
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
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
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
            buildButton("Errei", 0, Colors.red[800]!),
            buildButton("Difícil", 3, Colors.orange[800]!),
            buildButton("Bom", 4, Colors.blue[800]!),
            buildButton("Fácil", 5, Colors.green[800]!),
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
