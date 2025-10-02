import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_estudo.dart';
import 'package:nexo/screens/tela_jogo.dart';
import 'package:nexo/screens/tela_quizzes_lista.dart';
import 'package:nexo/screens/tela_realizar_quiz.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/quiz_service.dart';
import 'package:nexo/utils.dart';
import 'package:provider/provider.dart';


class TelaDetalheBaralho extends StatefulWidget {
  final Baralho baralho;

  const TelaDetalheBaralho({super.key, required this.baralho});

  @override
  _TelaDetalheBaralhoState createState() => _TelaDetalheBaralhoState();
}

class _TelaDetalheBaralhoState extends State<TelaDetalheBaralho> {
  late final FirestoreService _firestoreService;
  late final QuizService _quizService;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _quizService = context.read<QuizService>();
    _userId = FirebaseAuth.instance.currentUser!.uid;
  }


  void _adicionarCartao() {
    final frenteController = TextEditingController();
    final versoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Novo Cartão'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: frenteController,
                  decoration: const InputDecoration(labelText: 'Frente'),
                  validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                ),
                TextFormField(
                  controller: versoController,
                  decoration: const InputDecoration(labelText: 'Verso'),
                  validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final novoCartao = Cartao(
                    baralhoId: widget.baralho.id!,
                    frente: frenteController.text,
                    verso: versoController.text,
                  );
                  _firestoreService.addCard(novoCartao, _userId, widget.baralho.id!);
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

  void _importarCSV() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (resultado != null && resultado.files.single.bytes != null) {
        final bytes = resultado.files.single.bytes!;
        final conteudo = utf8.decode(bytes);
        final linhas = const CsvToListConverter().convert(conteudo);

        int cartoesImportados = 0;
        for (var i = 1; i < linhas.length; i++) { // Pula o cabeçalho
          final linha = linhas[i];
          if (linha.length >= 2) {
            final frente = linha[0].toString().trim();
            final verso = linha[1].toString().trim();
            if (frente.isNotEmpty && verso.isNotEmpty) {
              final novoCartao = Cartao(
                baralhoId: widget.baralho.id!,
                frente: frente,
                verso: verso,
              );
              await _firestoreService.addCard(novoCartao, _userId, widget.baralho.id!);
              cartoesImportados++;
            }
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$cartoesImportados cartões importados com sucesso!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      showErrorDialog(context, 'Erro ao Importar', 'Ocorreu um erro ao processar o arquivo CSV: $e');
    }
  }
  
  void _gerarProva(List<Cartao> cards) async {
    if (cards.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('É preciso ter pelo menos 4 cartões para gerar uma prova.'), backgroundColor: Colors.orangeAccent)
      );
      return;
    }
    
    try {
      final quiz = await _quizService.createQuiz(deckId: widget.baralho.id!, title: widget.baralho.nome, cards: cards);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => TelaRealizarQuiz(quiz: quiz),
        ));
      }
    } catch (e) {
      showErrorDialog(context, 'Erro ao Gerar Prova', e.toString());
    }
  }
  
  void _showResetDeckDialog() async {
    final bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar Progresso'),
        content: Text('Tem certeza que deseja resetar todo o progresso de estudo do baralho "${widget.baralho.nome}"? Todos os cartões voltarão ao estágio inicial.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Resetar", style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
    if(confirmar == true && mounted) {
      await _firestoreService.resetDeckProgress(_userId, widget.baralho.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progresso resetado com sucesso!'), backgroundColor: Colors.green),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baralho.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Resetar Progresso',
            onPressed: _showResetDeckDialog,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar CSV',
            onPressed: _importarCSV,
          ),
        ],
      ),
      body: StreamBuilder<List<Cartao>>(
        stream: _firestoreService.getCards(_userId, widget.baralho.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum cartão neste baralho ainda.'));
          }

          final cartoes = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Estudar (SRS)'),
                      onPressed: () {
                        final cardsToReview = cartoes.where((c) => c.proximaRevisao.isBefore(DateTime.now())).toList();
                          if (cardsToReview.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum cartão para revisar hoje!')));
                            return;
                          }
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TelaEstudo(baralho: widget.baralho, userId: _userId),
                        ));
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.videogame_asset),
                      label: const Text('Jogar'),
                      onPressed: cartoes.length < 4 ? null : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TelaJogo(cartoesDoBaralho: cartoes),
                        ));
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.quiz),
                      label: const Text('Gerar Prova'),
                      onPressed: () => _gerarProva(cartoes),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('Ver Provas'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TelaQuizzesLista(deckId: widget.baralho.id!, deckName: widget.baralho.nome),
                        ));
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 20, thickness: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: cartoes.length,
                  itemBuilder: (context, index) {
                    final cartao = cartoes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(cartao.frente),
                        subtitle: Text(cartao.verso),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarCartao,
        tooltip: 'Adicionar Cartão',
        child: const Icon(Icons.add),
      ),
    );
  }
}
