import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart'; // <<< PACOTE CORRETO

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
  late final WebViewController _controller;
  bool _isYouTube = false;

  @override
  void initState() {
    super.initState();

    String url = widget.videoUrl;
    // Converte links normais do YouTube para 'embed'
    if ((url.contains('youtube.com') || url.contains('youtu.be')) && !url.contains('embed')) {
      String? videoId;
      if (url.contains('youtu.be/')) {
        videoId = url.split('youtu.be/').last.split('?').first.split('&').first;
      } else if (url.contains('watch?v=')) {
         videoId = url.split('watch?v=').last.split('?').first.split('&').first;
      }
      if (videoId != null) {
        url = 'https://www.youtube.com/embed/$videoId?autoplay=1';
        _isYouTube = true;
      }
    } else if (url.contains('youtube.com/embed/')) {
      _isYouTube = true;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(url));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoTitle),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          // Usa o WebViewWidget universal
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
