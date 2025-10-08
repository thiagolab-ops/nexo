import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';

class TelaRecompensas extends StatelessWidget {
  const TelaRecompensas({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserModel?>();
    const int metaConvites = 50;

    if (userProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double progresso = userProfile.inviteCount / metaConvites;
    final String linkConvite = 'https://nexo-ee9a8.web.app/join?ref=${userProfile.username}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programa de Recompensas'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Tropa Daxu', // NOME ALTERADO
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Convide novos usuários para a plataforma e ganhe prêmios exclusivos!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                const Text(
                  'SUA META',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '${userProfile.inviteCount} / $metaConvites',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const Text('Usuários convidados'),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progresso > 1.0 ? 1.0 : progresso, // Garante que a barra não passe de 100%
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recompensa Final:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.workspace_premium, color: Colors.purple.shade300),
                          title: const Text('Assinatura Premium Vitalícia'),
                          subtitle: const Text('Acesso para sempre, sem anúncios.'),
                        ),
                        const ListTile(
                          leading: Icon(Icons.verified, color: Colors.blueAccent),
                          title: Text("Selo Exclusivo de 'Membro Fundador'"),
                          subtitle: Text('Uma marca permanente no seu perfil.'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar Meu Link de Convite'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: linkConvite));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copiado para a área de transferência!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
