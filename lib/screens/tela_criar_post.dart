import 'package:flutter/material.dart';
import 'package:nexo/services/feed_service.dart';

class TelaCriarPost extends StatefulWidget {
  const TelaCriarPost({super.key});

  @override
  State<TelaCriarPost> createState() => _TelaCriarPostState();
}

class _TelaCriarPostState extends State<TelaCriarPost> {
  final _textController = TextEditingController();
  final FeedService _feedService = FeedService();
  bool _isPosting = false;

  Future<void> _criarPost() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await _feedService.createPost(text: _textController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isPosting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar post: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _criarPost,
              child: _isPosting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Postar'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: 'No que você está pensando? Use "Frente --- Verso" para criar flashcards mágicos!',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
