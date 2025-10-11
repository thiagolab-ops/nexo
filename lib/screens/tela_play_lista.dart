import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nexo/games/nexo_build_screen.dart';
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
              'games_pageTitle'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_on, color: Colors.blueAccent),
            title: Text('games_daxuBuildTitle'.tr()),
            subtitle: Text('games_daxuBuildSubtitle'.tr()),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NexoBuildScreen(),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.checkroom_outlined, color: Colors.orangeAccent),
            title: Text('games_daxuChessTitle'.tr()),
            subtitle: Text('games_daxuChessSubtitle'.tr()),
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
