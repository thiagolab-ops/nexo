import 'dart:math';
import 'package:flutter/material.dart';
import 'tela_detalhe_baralho.dart';

class TelaEstudo extends StatefulWidget {
  final List<Cartao> cartoes;

  const TelaEstudo({super.key, required this.cartoes});

  @override
  State<TelaEstudo> createState() => _TelaEstudoState();
}

class _TelaEstudoState extends State<TelaEstudo> {
  late List<Cartao> _cartoesParaEstudar;
  int _indiceAtual = 0;
  bool _mostrandoFrente = true;

  @override
  void initState() {
    super.initState();
    // Filtra apenas os cartões que estão prontos para revisão hoje
    _cartoesParaEstudar = widget.cartoes.where((c) => c.proximaRevisao.isBefore(DateTime.now())).toList();
    _cartoesParaEstudar.shuffle(); // Embaralha para não ser previsível
  }

  void _processarResposta(Cartao cartao, int qualidade) {
    // qualidade: 0 (Errei), 1 (Difícil), 2 (Bom), 3 (Fácil)

    // <<< MUDANÇA PRINCIPAL AQUI >>>
    if (qualidade < 2) { // Se errou ou achou muito difícil
      // Reinicia o progresso do cartão
      cartao.intervalo = 0;
      // Adiciona o cartão de volta no final da fila para ser revisto nesta sessão
      // Para não ficar imediatamente em seguida, inserimos ele um pouco mais a frente
      int posicaoParaReinserir = min(_indiceAtual + 3, _cartoesParaEstudar.length);
      _cartoesParaEstudar.insert(posicaoParaReinserir, cartao);

    } else { // Se acertou (Bom ou Fácil)
      if (cartao.intervalo == 0) {
        cartao.intervalo = 1;
      } else if (cartao.intervalo == 1) {
        cartao.intervalo = 6;
      } else {
        cartao.intervalo = (cartao.intervalo * cartao.easeFactor).round();
      }
       // Remove o cartão da lista de estudo desta sessão, já que foi acertado
      _cartoesParaEstudar.removeAt(_indiceAtual);
      // Ajusta o índice para não pular um cartão
      _indiceAtual--;
    }

    // Ajusta o fator de facilidade (só se não errou)
    if (qualidade >= 2) {
      cartao.easeFactor += (0.1 - (3 - qualidade) * (0.08 + (3 - qualidade) * 0.02));
      if (cartao.easeFactor < 1.3) cartao.easeFactor = 1.3;
    }

    cartao.proximaRevisao = DateTime.now().add(Duration(days: cartao.intervalo));

    _proximoCartao();
  }

  void _proximoCartao() {
    if (!mounted) return;
    setState(() {
      // Se o índice for maior que o tamanho da lista, fim de sessão
      if (_indiceAtual >= _cartoesParaEstudar.length - 1) {
        Navigator.of(context).pop('estudou');
      } else {
        _indiceAtual++;
        _mostrandoFrente = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cartoesParaEstudar.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessão Concluída')),
        body: const Center(
          child: Text(
            'Parabéns! Nenhum cartão para estudar hoje.',
            style: TextStyle(color: Colors.white, fontSize: 22),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final cartaoAtual = _cartoesParaEstudar[_indiceAtual];

    return Scaffold(
      appBar: AppBar(
        title: Text('Estudando... (${_indiceAtual + 1}/${_cartoesParaEstudar.length})'),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _mostrandoFrente = !_mostrandoFrente),
        child: Center(
          child: Card(
            color: Colors.blueGrey[800],
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Text(
                _mostrandoFrente ? cartaoAtual.frente : cartaoAtual.verso,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _mostrandoFrente
          ? null
          : BottomAppBar(
              color: Colors.transparent,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBotaoResposta('Errei', Colors.red, 0, cartaoAtual),
                    _buildBotaoResposta('Difícil', Colors.orange, 1, cartaoAtual),
                    _buildBotaoResposta('Bom', Colors.lightGreen, 2, cartaoAtual),
                    _buildBotaoResposta('Fácil', Colors.green, 3, cartaoAtual),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBotaoResposta(String texto, Color cor, int qualidade, Cartao cartao) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () => _processarResposta(cartao, qualidade),
          style: ElevatedButton.styleFrom(backgroundColor: cor),
          child: Text(texto),
        ),
      ),
    );
  }
}
