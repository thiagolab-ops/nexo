import 'package:flutter/material.dart';
import 'main.dart';
import 'tela_estudo.dart';

class Cartao {
  final int id;
  String frente;
  String verso;
  String? imagemUrl;
  DateTime proximaRevisao;
  int intervalo;
  double easeFactor;

  Cartao({
    required this.frente,
    required this.verso,
    this.imagemUrl,
    DateTime? proximaRevisao,
    this.intervalo = 0,
    this.easeFactor = 2.5,
  }) : id = DateTime.now().millisecondsSinceEpoch,
       proximaRevisao = proximaRevisao ?? DateTime.now();
}

class TelaDetalheBaralho extends StatefulWidget {
  final Baralho baralho;
  const TelaDetalheBaralho({super.key, required this.baralho});

  @override
  State<TelaDetalheBaralho> createState() => _TelaDetalheBaralhoState();
}

class _TelaDetalheBaralhoState extends State<TelaDetalheBaralho> {
  void _mostrarDialogoEditarCartao({Cartao? cartao}) {
    final frenteController = TextEditingController(text: cartao?.frente ?? '');
    final versoController = TextEditingController(text: cartao?.verso ?? '');
    final imagemUrlController = TextEditingController(text: cartao?.imagemUrl ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[800],
          title: Text(cartao == null ? 'Novo Cartão' : 'Editar Cartão', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: frenteController, autofocus: true, decoration: const InputDecoration(hintText: 'Frente'), style: const TextStyle(color: Colors.white)),
                TextField(controller: versoController, decoration: const InputDecoration(hintText: 'Verso'), style: const TextStyle(color: Colors.white)),
                TextField(controller: imagemUrlController, decoration: const InputDecoration(hintText: 'URL da Imagem (opcional)'), style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final frente = frenteController.text;
                final verso = versoController.text;
                if (frente.isNotEmpty && verso.isNotEmpty) {
                  setState(() {
                    if (cartao == null) {
                      widget.baralho.cartoes.add(Cartao(frente: frente, verso: verso, imagemUrl: imagemUrlController.text));
                    } else {
                      cartao.frente = frente;
                      cartao.verso = verso;
                      cartao.imagemUrl = imagemUrlController.text;
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text(cartao == null ? 'Adicionar' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoExcluirCartao(Cartao cartao) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[800],
          title: const Text('Confirmar Exclusão', style: TextStyle(color: Colors.white)),
          content: const Text('Tem certeza que deseja excluir este cartão permanentemente?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  widget.baralho.cartoes.removeWhere((c) => c.id == cartao.id);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.baralho.totalDeCartoes = widget.baralho.cartoes.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baralho.nome),
        actions: [
          if (widget.baralho.cartoes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Estudar',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TelaEstudo(cartoes: widget.baralho.cartoes),
                  ),
                ).then((_) {
                   Navigator.of(context).pop('estudou');
                });
              },
            )
        ],
      ),
      body: ListView.builder(
        itemCount: widget.baralho.cartoes.length,
        itemBuilder: (context, index) {
          final cartao = widget.baralho.cartoes[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.blueGrey[800],
            child: ListTile(
              leading: cartao.imagemUrl != null && cartao.imagemUrl!.isNotEmpty
                  ? Image.network(cartao.imagemUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red))
                  : const Icon(Icons.image_not_supported, color: Colors.white24),
              title: Text(cartao.frente, style: const TextStyle(color: Colors.white)),
              subtitle: Text(cartao.verso, style: const TextStyle(color: Colors.white70)),
              trailing: PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: Colors.blueGrey[700],
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'editar',
                    child: const Text('Editar', style: TextStyle(color: Colors.white)),
                    onTap: () => _mostrarDialogoEditarCartao(cartao: cartao),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                    onTap: () => _mostrarDialogoExcluirCartao(cartao),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ()=>_mostrarDialogoEditarCartao(),
        tooltip: 'Adicionar Cartão',
        child: const Icon(Icons.add_card),
      ),
    );
  }
}
