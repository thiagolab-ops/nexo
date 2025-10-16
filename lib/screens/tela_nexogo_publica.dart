import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_curso_player.dart';
import 'package:nexo/screens/tela_video_player_generica.dart';

class TelaNexoGoPublica extends StatefulWidget {
  final UserModel profUser;
  const TelaNexoGoPublica({super.key, required this.profUser});

  @override
  State<TelaNexoGoPublica> createState() => _TelaNexoGoPublicaState();
}

class _TelaNexoGoPublicaState extends State<TelaNexoGoPublica> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose(){
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.school_outlined), text: 'daxugo_coursesPublicTab'.tr()),
            Tab(icon: const Icon(Icons.video_collection_outlined), text: 'daxugo_videosPublicTab'.tr()),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCursosList(context),
              _buildArquivosList(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCursosList(BuildContext context) {
    return StreamBuilder<List<Curso>>(
      stream: FirebaseFirestore.instance
          .collection('public_courses')
          .where('ownerId', isEqualTo: widget.profUser.id)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Curso.fromFirestore(doc)).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Erro ao carregar cursos: ${snapshot.error}')));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('daxugo_noCoursesPublic'.tr()));
        
        final cursos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: cursos.length,
          itemBuilder: (context, index) {
            final curso = cursos[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.school, size: 40),
                title: Text(curso.title),
                subtitle: Text(curso.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(curso.averageRating.toStringAsFixed(1)),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaCursoPlayer(curso: curso, profProfile: widget.profUser),
                  ));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArquivosList(BuildContext context) {
    return StreamBuilder<List<VideoNexo>>(
      stream: FirebaseFirestore.instance
          .collection('public_videos')
          .where('ownerId', isEqualTo: widget.profUser.id)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => VideoNexo.fromFirestore(doc)).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Erro ao carregar vídeos: ${snapshot.error}')));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('daxugo_noVideosPublic'.tr()));
        
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
                title: Text(video.title),
                subtitle: Text(video.subject),
                trailing: const Icon(Icons.play_arrow),
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
}
