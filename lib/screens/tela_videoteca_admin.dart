import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_video_form.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TelaVideotecaAdmin extends StatefulWidget {
  const TelaVideotecaAdmin({super.key});

  @override
  State<TelaVideotecaAdmin> createState() => _TelaVideotecaAdminState();
}

class _TelaVideotecaAdminState extends State<TelaVideotecaAdmin> {
  late final FirestoreService _firestoreService;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  void _showDeleteDialog(VideoNexo video) async {
     final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Vídeo'),
        content: Text('Tem certeza que deseja excluir "${video.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteVideo(_currentUserId, video.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Videoteca'),
      ),
      body: StreamBuilder<List<VideoNexo>>(
        stream: _firestoreService.streamVideos(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum vídeo adicionado ainda.\nClique em + para começar.', textAlign: TextAlign.center));
          }
          final videos = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              final thumbnailUrl = video.thumbnailUrl; // Usa nosso getter do modelo!

              return Card(
                elevation: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mostra a Thumbnail do YouTube
                    if (thumbnailUrl.isNotEmpty)
                      Image.network(
                        thumbnailUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: const Center(child: Icon(Icons.videocam_off)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(video.subject, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          Text(video.title, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(video.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey),
                          tooltip: 'Editar',
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => TelaVideoForm(videoToEdit: video),
                            ));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          tooltip: 'Excluir',
                          onPressed: () => _showDeleteDialog(video),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const TelaVideoForm(),
          ));
        },
        tooltip: 'Adicionar Vídeo',
        child: const Icon(Icons.add),
      ),
    );
  }
}
