import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class TelaVideoPlayerGenerica extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;

  const TelaVideoPlayerGenerica({
    super.key, 
    required this.videoUrl, 
    this.videoTitle = 'Nexo Go',
  });

  @override
  State<TelaVideoPlayerGenerica> createState() => _TelaVideoPlayerGenericaState();
}

class _TelaVideoPlayerGenericaState extends State<TelaVideoPlayerGenerica> {
  late YoutubePlayerController _ytController;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl);

    if (videoId != null) {
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          color: 'red',
        ),
      );
      // A linha '..onInit = ()' foi removida daqui.
      _isPlayerReady = true; // Nós sabemos que está pronto se o videoId for válido
    } else {
      _isPlayerReady = false;
    }
  }

  @override
  void dispose() {
    if (_isPlayerReady) { // Só fecha o controller se ele foi inicializado
      _ytController.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoTitle),
      ),
      body: Center(
        child: _isPlayerReady
          ? YoutubePlayer( // O nome do widget estava correto
              controller: _ytController,
              aspectRatio: 16 / 9,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text('Não foi possível carregar este vídeo.', style: GoogleFonts.lato(fontSize: 18)),
                Text('A URL pode ser inválida ou não ser do YouTube.', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey)),
              ],
            ),
      ),
    );
  }
}
