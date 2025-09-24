import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexogo_arquivo_form.dart';
import 'package:nexo/screens/tela_nexogo_curso_detalhe.dart';
import 'package:nexo/screens/tela_nexogo_curso_form.dart';
import 'package:nexo/screens/tela_video_player_generica.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TelaNexoGoAdmin extends StatefulWidget {
  const TelaNexoGoAdmin({super.key});

  @override
  State<TelaNexoGoAdmin> createState() => _TelaNexoGoAdminState();
}

class _TelaNexoGoAdminState extends State<TelaNexoGoAdmin> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final FirestoreService _firestoreService;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDeleteVideoDialog(VideoNexo video) async {
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

  void _showDeleteCursoDialog(Curso curso) async {
     final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Curso'),
        content: Text('Tem certeza que deseja excluir o curso "${curso.title}"? (Isso não deletará as aulas, por enquanto.)'),
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
      await _firestoreService.deleteCurso(_currentUserId, curso.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Daxu Go'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined), text: 'CURSOS'),
            Tab(icon: Icon(Icons.video_collection_outlined), text: 'VÍDEOS'), // <<< NOME ATUALIZADO
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCursosList(),
          _buildArquivosList(), // Trocado a ordem para combinar com a TabBar
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
             Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const TelaNexoGoCursoForm(),
            ));
          } else {
             Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const TelaNexoGoArquivoForm(),
            ));
          }
        },
        tooltip: _tabController.index == 0 ? 'Adicionar Curso' : 'Adicionar Vídeo',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildArquivosList() {
    return StreamBuilder<List<VideoNexo>>(
      stream: _firestoreService.streamVideos(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum vídeo adicionado.'));
        
        final videos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final thumbnailUrl = video.thumbnailUrl;

            return Card(
              child: ListTile(
                leading: thumbnailUrl.isNotEmpty 
                  ? Image.network(thumbnailUrl, width: 100, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.videocam)) 
                  : const Icon(Icons.videocam, size: 60),
                title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(video.subject, maxLines: 1),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TelaNexoGoArquivoForm(videoToEdit: video),
                        )),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => _showDeleteVideoDialog(video),
                      ),
                  ],
                ),
                onTap: () {
                   Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TelaVideoPlayerGenerica(videoUrl: video.videoUrl, videoTitle: video.title),
                   ));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCursosList() {
     return StreamBuilder<List<Curso>>(
      stream: _firestoreService.streamCursos(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum curso criado.'));
        
        final cursos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: cursos.length,
          itemBuilder: (context, index) {
            final curso = cursos[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.school, size: 60), 
                title: Text(curso.title),
                subtitle: Text(curso.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                 trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TelaNexoGoCursoForm(cursoToEdit: curso),
                        )),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => _showDeleteCursoDialog(curso),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaNexoGoCursoDetalhe(curso: curso),
                  ));
                },
              ),
            );
          },
        );
      },
    );
  }
}
