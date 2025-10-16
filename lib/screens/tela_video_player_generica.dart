import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

class TelaVideoPlayerGenerica extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  const TelaVideoPlayerGenerica({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
  });

  @override
  State<TelaVideoPlayerGenerica> createState() => _TelaVideoPlayerGenericaState();
}

class _TelaVideoPlayerGenericaState extends State<TelaVideoPlayerGenerica> {
  late String _currentVideoUrl;
  final String _iframeId = 'generic-video-player-iframe-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = _formatUrl(widget.videoUrl);

    ui.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) => html.IFrameElement()
        ..width = '100%'
        ..height = '100%'
        ..src = _currentVideoUrl
        ..style.border = 'none'
        ..allowFullscreen = true
        ..allow = 'autoplay; fullscreen; picture-in-picture',
    );
  }

  String _formatUrl(String url) {
    String videoUrl = url;
    if ((videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) && !videoUrl.contains('embed')) {
      String? videoId;
      if (videoUrl.contains('youtu.be/')) {
        videoId = videoUrl.split('youtu.be/').last.split('?').first.split('&').first;
      } else if (videoUrl.contains('watch?v=')) {
        videoId = videoUrl.split('watch?v=').last.split('?').first.split('&').first;
      }
      if (videoId != null) {
        videoUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1&fs=1';
      }
    }
     if (!videoUrl.contains('autoplay=1') && (videoUrl.contains('youtube.com') || videoUrl.contains('vimeo.com'))) {
        videoUrl = videoUrl.contains('?') ? '$videoUrl&autoplay=1' : '$videoUrl?autoplay=1';
    }
    return videoUrl;
  }

  @override
  void didUpdateWidget(covariant TelaVideoPlayerGenerica oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _currentVideoUrl = _formatUrl(widget.videoUrl);
      (html.document.getElementById(_iframeId) as html.IFrameElement?)?.src = _currentVideoUrl;
    }
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
          child: HtmlElementView(viewType: _iframeId),
        ),
      ),
    );
  }
}
