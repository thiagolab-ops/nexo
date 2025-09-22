import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';

class PerfilForumTab extends StatelessWidget {
  final String userId;
  const PerfilForumTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Aponta para a coleção global de tópicos
    final topicsRef = FirebaseFirestore.instance.collection('topics');

    return StreamBuilder<QuerySnapshot>(
      // Busca todos os tópicos onde 'authorId' == o ID deste perfil,
      // ordenados pelo mais recente.
      stream: topicsRef
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erro ao carregar tópicos. (Verifique o índice do Firestore)'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Este usuário ainda não criou nenhum tópico.'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final bool isClosed = data['isClosed'] ?? false;
            final String? bestAnswerId = data['bestAnswerId'];

            // (Não precisamos navegar daqui, então usamos um ListTile simples)
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(data['title'] ?? 'Sem Título'),
                subtitle: Text(data['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(bestAnswerId != null) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                    if(isClosed) const Icon(Icons.lock, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
