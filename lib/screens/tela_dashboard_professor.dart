import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';

class TelaDashboardProfessor extends StatefulWidget {
  const TelaDashboardProfessor({super.key});

  @override
  State<TelaDashboardProfessor> createState() => _TelaDashboardProfessorState();
}

class _TelaDashboardProfessorState extends State<TelaDashboardProfessor> {
  final ProfileService _profileService = ProfileService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Erro: Usuário não autenticado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Performance'),
      ),
      body: StreamBuilder<ProfessorStats?>(
        stream: _profileService.getProfessorStatsStream(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar estatísticas: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Ainda não há estatísticas para exibir.\nContinue postando!', textAlign: TextAlign.center),
            );
          }

          final stats = snapshot.data!;

          return GridView.count(
            padding: const EdgeInsets.all(16.0),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                icon: Icons.article,
                label: 'Posts Criados',
                value: stats.postCount.toString(),
                color: Colors.blueAccent,
              ),
              _buildStatCard(
                icon: Icons.favorite,
                label: 'Total de Likes',
                value: stats.totalLikes.toString(),
                color: Colors.redAccent,
              ),
              _buildStatCard(
                icon: Icons.comment,
                label: 'Total de Comentários',
                value: stats.totalComments.toString(),
                color: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.style,
                label: 'Baralhos Gerados',
                value: stats.totalDeckCreations.toString(),
                color: Colors.orangeAccent,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
