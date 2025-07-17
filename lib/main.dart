import 'package:flutter/material.dart';
import 'tela_detalhe_baralho.dart';
import 'tela_jogo.dart';
import 'baralho_card_widget.dart';

class Baralho {
  String nome;
  int totalDeCartoes;
  List<Cartao> cartoes;
  int ofensiva;
  DateTime? ultimaSessao;

  double get progresso {
    if (cartoes.isEmpty) return 0.0;
    final cartoesAprendidos = cartoes.where((c) => c.intervalo >= 6).length;
    return cartoesAprendidos / cartoes.length;
  }

  Baralho({
    required this.nome,
    this.totalDeCartoes = 0,
    List<Cartao>? cartoes,
    this.ofensiva = 0,
    this.ultimaSessao,
  }) : cartoes = cartoes ?? [];
}

void main() {
  runApp(const NexoApp());
}

class NexoApp extends StatelessWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final List<Baralho> _baralhos = [];

  void _mostrarDialogoNovoBaralho() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[800],
          title: const Text('Novo Baralho', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nome do baralho'),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final nomeDoBaralho = textController.text;
                if (nomeDoBaralho.isNotEmpty) {
                  setState(() {
                    _baralhos.add(Baralho(nome: nomeDoBaralho));
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _processarRetornoEstudo(Baralho baralho) {
    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (baralho.ultimaSessao != null) {
      final ultimaSessaoData = DateTime(baralho.ultimaSessao!.year, baralho.ultimaSessao!.month, baralho.ultimaSessao!.day);
      final umDiaAtras = hoje.subtract(const Duration(days: 1));

      if (ultimaSessaoData.isAtSameMomentAs(umDiaAtras)) {
        baralho.ofensiva++;
      } 
      else if (!ultimaSessaoData.isAtSameMomentAs(hoje)) {
        baralho.ofensiva = 1;
      }
    } else {
      baralho.ofensiva = 1;
    }

    baralho.ultimaSessao = DateTime.now();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.blueGrey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(child: Text('NEXO', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 100, color: Colors.white.withOpacity(0.05)))),
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text('Meus Baralhos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    floating: true,
                  ),
                  _baralhos.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Nenhum baralho ainda.\nClique em + para adicionar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final baralho = _baralhos[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: BaralhoCardWidget(
                                    baralho: baralho,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (context) => TelaDetalheBaralho(baralho: baralho)),
                                      ).then((valor) {
                                        if (valor == 'estudou') {
                                          _processarRetornoEstudo(baralho);
                                        } else {
                                          setState((){});
                                        }
                                      });
                                    },
                                    onPlay: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (context) => TelaJogo(cartoesDoBaralho: baralho.cartoes)),
                                      ).then((_) => _processarRetornoEstudo(baralho));
                                    },
                                  ),
                                );
                              },
                              childCount: _baralhos.length,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNovoBaralho,
        tooltip: 'Adicionar Baralho',
        backgroundColor: Colors.lightBlueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
