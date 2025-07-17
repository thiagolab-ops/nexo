import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'tela_detalhe_baralho.dart';

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
  int _pontos = 0;
  Timer? _timer;
  int _tempoRestante = 60;

  // <<< NOVOS ESTADOS PARA O FEEDBACK >>>
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _mostrandoAnimacaoSucesso = false;
  bool _mostrandoAnimacaoFalha = false;

  @override
  void initState() {
    super.initState();
    _iniciarJogo();
    _iniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_tempoRestante > 0) {
        if (mounted) setState(() => _tempoRestante--);
      } else {
        timer.cancel();
      }
    });
  }

  void _iniciarJogo() {
    final todosOsCartoes = List<Cartao>.from(widget.cartoesDoBaralho);
    todosOsCartoes.shuffle();
    _pares = todosOsCartoes.take(min(5, todosOsCartoes.length)).toList();
    _opcoesFrente = _pares.map((p) => p.frente).toList()..shuffle();
    _opcoesVerso = _pares.map((p) => p.verso).toList()..shuffle();
  }

  void _verificarCombinacao() {
    if (_frenteSelecionada == null || _versoSelecionado == null) return;

    final parCorreto = _pares.firstWhere((p) => p.frente == _frenteSelecionada);

    if (parCorreto.verso == _versoSelecionado) {
      // <<< LÓGICA DE ACERTO >>>
      _audioPlayer.play(AssetSource('sounds/correct.mp3'));
      setState(() {
        _mostrandoAnimacaoSucesso = true;
        _pontos++;
        _opcoesFrente.remove(_frenteSelecionada);
        _opcoesVerso.remove(_versoSelecionado);
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _mostrandoAnimacaoSucesso = false);
      });

    } else {
      // <<< LÓGICA DE ERRO >>>
      _audioPlayer.play(AssetSource('sounds/wrong.mp3'));
      setState(() => _mostrandoAnimacaoFalha = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _mostrandoAnimacaoFalha = false);
      });
    }

    // Limpa a seleção
    setState(() {
      _frenteSelecionada = null;
      _versoSelecionado = null;
    });

    if (_opcoesFrente.isEmpty) {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combine os Pares!'),
        actions: [
          Center(child: Text('Pontos: $_pontos', style: const TextStyle(fontSize: 18))),
          const SizedBox(width: 16),
          Center(child: Text('Tempo: $_tempoRestante', style: const TextStyle(fontSize: 18))),
          const SizedBox(width: 16),
        ],
      ),
      // <<< USAMOS UM STACK PARA MOSTRAR AS ANIMAÇÕES POR CIMA DO JOGO >>>
      body: Stack(
        children: [
          // O Jogo em si
          if (_opcoesFrente.length < 2)
            const Center(child: Text('Você precisa de pelo menos 2 cartões para jogar.', style: TextStyle(color: Colors.white)))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _construirColunaDeOpcoes(_opcoesFrente, true),
                _construirColunaDeOpcoes(_opcoesVerso, false),
              ],
            ),

          // Animação de Sucesso
          if (_mostrandoAnimacaoSucesso)
            Center(child: Lottie.asset('assets/animations/success.json', repeat: false)),

          // Animação de Falha
          if (_mostrandoAnimacaoFalha)
            Center(child: Lottie.asset('assets/animations/failure.json', repeat: false)),
        ],
      ),
    );
  }

  Widget _construirColunaDeOpcoes(List<String> opcoes, bool isFrente) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: opcoes.map((texto) {
          final isSelected = isFrente ? texto == _frenteSelecionada : texto == _versoSelecionado;
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? Colors.lightBlue : Colors.blueGrey[700],
              minimumSize: const Size(150, 60),
            ),
            onPressed: () {
              setState(() => isFrente ? _frenteSelecionada = texto : _versoSelecionado = texto);
              _verificarCombinacao();
            },
            child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
    );
  }
}
