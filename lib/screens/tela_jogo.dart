import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

class TelaJogo extends StatefulWidget {
  final List<Cartao> cartoesDoBaralho;
  const TelaJogo({super.key, required this.cartoesDoBaralho});

  @override
  State<TelaJogo> createState() => _TelaJogoState();
}

class _TelaJogoState extends State<TelaJogo> {
  late List<Cartao> _pares;
  late List<String> _opcoesFrente;
  late List<String> _opcoesVerso;

  String? _frenteSelecionada;
  String? _versoSelecionado;

  Map<String, bool> _acertosFrente = {};
  Map<String, bool> _acertosVerso = {};

  @override
  void initState() {
    super.initState();
    _iniciarJogo();
  }

  void _iniciarJogo() {
    final todosOsCartoes = List<Cartao>.from(widget.cartoesDoBaralho)..shuffle();
    _pares = todosOsCartoes.take(6).toList();

    _opcoesFrente = _pares.map((p) => p.frente).toList()..shuffle();
    _opcoesVerso = _pares.map((p) => p.verso).toList()..shuffle();

    _frenteSelecionada = null;
    _versoSelecionado = null;
    _acertosFrente = {};
    _acertosVerso = {};
  }

  void _selecionarFrente(String frente) {
    setState(() {
      _frenteSelecionada = frente;
      _verificarPar();
    });
  }

  void _selecionarVerso(String verso) {
    setState(() {
      _versoSelecionado = verso;
      _verificarPar();
    });
  }

  void _verificarPar() {
    if (_frenteSelecionada != null && _versoSelecionado != null) {
      final parCorreto = _pares.firstWhere((p) => p.frente == _frenteSelecionada);

      if (parCorreto.verso == _versoSelecionado) {
        setState(() {
          _acertosFrente[_frenteSelecionada!] = true;
          _acertosVerso[_versoSelecionado!] = true;
          _frenteSelecionada = null;
          _versoSelecionado = null;
        });

        if (_acertosFrente.length == _pares.length) {
          _mostrarDialogoVitoria();
        }
      } else {
        // Deseleciona ambos após 500ms para o usuário ver o erro
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _frenteSelecionada = null;
            _versoSelecionado = null;
          });
        });
      }
    }
  }

  void _mostrarDialogoVitoria() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('congratulations'.tr()),
        content: Text('gameComplete'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fecha o diálogo
              Navigator.of(context).pop(); // Volta para a tela anterior
            },
            child: Text('backButton'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _iniciarJogo();
              });
            },
            child: Text('playAgainButton'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('memoryGameTitle'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildColunaDeOpcoes(_opcoesFrente, _frenteSelecionada, _acertosFrente, _selecionarFrente),
            _buildColunaDeOpcoes(_opcoesVerso, _versoSelecionado, _acertosVerso, _selecionarVerso),
          ],
        ),
      ),
    );
  }

  Widget _buildColunaDeOpcoes(List<String> opcoes, String? selecionado, Map<String, bool> acertos, Function(String) onSelecionado) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: opcoes.map((texto) {
          final estaSelecionado = selecionado == texto;
          final jaAcertou = acertos[texto] ?? false;

          Color cor;
          if (jaAcertou) {
            cor = Colors.green.withOpacity(0.5);
          } else if (estaSelecionado) {
            cor = Colors.blue;
          } else {
            cor = Colors.grey[800]!;
          }

          return Expanded(
            child: GestureDetector(
              onTap: jaAcertou ? null : () => onSelecionado(texto),
              child: Card(
                color: cor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
