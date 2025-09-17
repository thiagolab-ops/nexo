import 'package:flutter/material.dart';
import 'package:nexo/games/nexo_build_screen.dart'; // <<< JOGO 2 IMPORTADO
import 'package:nexo/games/nexo_chess_screen.dart'; 

class TelaPlayLista extends StatelessWidget {
  const TelaPlayLista({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Nexo Play',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_on, color: Colors.blueAccent),
            title: const Text('Nexo Build (Tetris)'),
            subtitle: const Text('Desafie seu raciocínio espacial.'),
            onTap: () {
              // --- NAVEGAÇÃO ADICIONADA ---
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NexoBuildScreen(),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.checkroom_outlined, color: Colors.orangeAccent), 
            title: const Text('Nexo Chess (Xadrez Rápido)'),
            subtitle: const Text('Teste sua lógica contra a IA.'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NexoChessScreen(),
              ));
            },
          ),
        ],
      ),
    );
  }
}
