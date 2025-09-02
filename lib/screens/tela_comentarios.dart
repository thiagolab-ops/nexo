import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/feed_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;

class TelaComentarios extends StatefulWidget {
  final Post post;
  const TelaComentarios({super.key, required this.post});

  @override
  State<TelaComentarios> createState() => _TelaComentariosState();
}

class _TelaComentariosState extends State<TelaComentarios> {
  final _commentController = TextEditingController();
  final _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final text = _commentController.text.trim();
    _commentController.clear();

    try {
      await _feedService.addComment(widget.post.id, text);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print("Erro ao postar comentário: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao comentar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _showDeleteConfirmationDialog(Comment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Comentário'),
        content: const Text('Tem certeza que deseja excluir este comentário permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _feedService.deleteComment(widget.post.id, comment.id);
              } catch (e) {
                if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comentários'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _feedService.getCommentsStream(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum comentário ainda. Seja o primeiro!'));
                }
                final comments = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final bool canDelete = (_currentUserId == comment.authorId) || (_currentUserId == widget.post.authorId);

                    return ListTile(
                      leading: UserAvatar(username: comment.authorUsername, photoUrl: comment.authorPhotoUrl),
                      title: Text(comment.authorUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(comment.text),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeago.format(comment.createdAt.toDate(), locale: 'pt_BR'),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                          ),
                          if (canDelete)
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade600),
                              tooltip: 'Excluir comentário',
                              onPressed: () => _showDeleteConfirmationDialog(comment),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Adicione um comentário...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _postComment(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _postComment,
          ),
        ],
      ),
    );
  }
}
