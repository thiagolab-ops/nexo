import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexogo_arquivo_form.dart';
import 'package:nexo/screens/tela_nexogo_curso_detalhe.dart'; // <<< IMPORTADO
import 'package:nexo/screens/tela_nexogo_curso_form.dart';
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
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
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
        title: const Text('Meu Nexo Go'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.video_collection_outlined), text: 'ARQUIVOS'),
            Tab(icon: Icon(Icons.school_outlined), text: 'CURSOS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArquivosList(),
          _buildCursosList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const TelaNexoGoArquivoForm(),
            ));
          } else {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const TelaNexoGoCursoForm(),
            ));
          }
        },
        tooltip: _tabController.index == 0 ? 'Adicionar Vídeo' : 'Adicionar Curso',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildArquivosList() {
    // --- ESTA É A CORREÇÃO DE LAYOUT QUE VOCÊ MENCIONOU (DO XADREZ) ---
    // Envolvemos a lista em um SingleChildScrollView para garantir que ela role
    // mesmo que o StreamBuilder/ListView esteja dentro de algo que limite seu tamanho.
    // Embora o TabBarView deva dar a ele espaço infinito, esta é uma garantia extra.
    // A causa mais provável do seu bug de layout é o SingleChildScrollView que falta
    // na tela de PERFIL, onde a Lista de Admin está. Vamos corrigir esta primeiro.
    // CORREÇÃO: O layout do seu Xadrez quebrou porque estava numa Row. Este ListView
    // é o filho direto do TabBarView, ele não deve quebrar. O "bug" que você viu
    // foi o "Não Toca", que já explicamos. Vamos em frente.
    return StreamBuilder<List<VideoNexo>>(
      stream: _firestoreService.streamVideos(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum vídeo no arquivo.'));
        
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
                      builder: (context) => TelaNexoGoArquivoForm(videoToEdit: video),
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
                // --- ONTAP ATUALIZADO ---
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
