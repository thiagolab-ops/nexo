import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TelaAprovacaoProfessor extends StatefulWidget {
  const TelaAprovacaoProfessor({super.key});

  @override
  State<TelaAprovacaoProfessor> createState() => _TelaAprovacaoProfessorState();
}

class _TelaAprovacaoProfessorState extends State<TelaAprovacaoProfessor> {
  final _applicationsRef = FirebaseFirestore.instance.collection('professor_applications');

  Future<void> _approve(String docId, String userId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final applicationRef = _applicationsRef.doc(docId);

      final batch = FirebaseFirestore.instance.batch();
      batch.update(userRef, {'role': 'professor'});
      batch.delete(applicationRef);

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário aprovado como professor!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decline(String docId) async {
    await _applicationsRef.doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação recusada.'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprovar Professores'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _applicationsRef.where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma solicitação pendente.'));
          }

          final applications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final doc = applications[index];
              final data = doc.data() as Map<String, dynamic>;
              final userId = data['userId'] ?? 'ID não encontrado';
              final username = data['applicantUsername'] ?? 'Username não encontrado';

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: Theme.of(context).textTheme.titleLarge),
                      const Divider(),
                      Text('Especialidades: ${data['specialties'] ?? 'N/A'}'),
                      const SizedBox(height: 8),
                      Text('Links: ${data['socialLinks'] ?? 'N/A'}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _decline(doc.id),
                            child: const Text('Recusar', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _approve(doc.id, userId),
                            child: const Text('Aprovar'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
