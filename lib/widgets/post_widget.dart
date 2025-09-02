import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_comentarios.dart';
import 'package:nexo/screens/tela_perfil_usuario.dart';
import 'package:nexo/services/feed_service.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/report_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:nexo/utils.dart';


class PostWidget extends StatefulWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  final FeedService _feedService = FeedService();
  final FirestoreService _firestoreService = FirestoreService();
  final ReportService _reportService = ReportService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.likes.contains(_currentUserId);
    _likeCount = widget.post.likes.length;
  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.likes.length != _likeCount || widget.post.likes.contains(_currentUserId) != _isLiked) {
      setState(() {
        _isLiked = widget.post.likes.contains(_currentUserId);
        _likeCount = widget.post.likes.length;
      });
    }
  }
  
  void _showReportDialog() {
    String? selectedReason;
    final reasons = ['Spam', 'Conteúdo de Ódio', 'Assédio ou Bullying', 'Outro'];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Denunciar Post'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Por favor, selecione o motivo da denúncia:'),
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  )).toList(),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: selectedReason == null ? null : () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    if (_currentUserId == null) return;
                    
                    final report = ReportModel(
                      id: '',
                      reporterId: _currentUserId!,
                      reportedUserId: widget.post.authorId,
                      contentId: widget.post.id,
                      contentType: 'post',
                      reason: selectedReason!,
                      createdAt: Timestamp.now(),
                    );
                    
                    try {
                      await _reportService.submitReport(report);
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Denúncia enviada com sucesso. Agradecemos sua colaboração!'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                       navigator.pop();
                       showErrorDialog(context, 'Erro', 'Não foi possível enviar a denúncia.');
                    }
                  },
                  child: const Text('Enviar Denúncia'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) { _likeCount++; } else { _likeCount--; }
    });
    _feedService.toggleLike(widget.post.id, !_isLiked);
  }
  
  void _sharePost() {
    final textToShare = 'Confira este post de @${widget.post.authorUsername} no app Nexo!\n\n"${widget.post.text}"';
    Share.share(textToShare, subject: 'Post de ${widget.post.authorUsername}');
  }

  void _handleCreateDeck() {
    // ... (código existente, sem alterações)
  }

  void _navigateToUserProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => TelaPerfilUsuario(userId: widget.post.authorId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
    final bool isOwnPost = widget.post.authorId == _currentUserId;

    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _navigateToUserProfile,
                child: UserAvatar(username: widget.post.authorUsername, photoUrl: widget.post.authorPhotoUrl, radius: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _navigateToUserProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.authorUsername, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      Text(
                        timeago.format(widget.post.createdAt.toDate(), locale: 'pt_BR'),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isOwnPost)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'report') {
                      _showReportDialog();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('Denunciar'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48.0),
            child: Text(widget.post.text),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _likeCount.toString(),
                  onTap: _handleLike,
                  color: _isLiked ? Colors.redAccent : Colors.grey.shade500,
                ),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: widget.post.commentCount.toString(),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TelaComentarios(post: widget.post),
                    ));
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Compartilhar',
                  onTap: _sharePost,
                ),
                const Spacer(),
                _buildActionButton(
                  icon: Icons.style_outlined, 
                  label: '',
                  onTap: _handleCreateDeck, 
                  isPrimary: true
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, Color? color, bool isPrimary = false}) {
    final actionColor = isPrimary ? Colors.lightBlueAccent : color ?? Colors.grey.shade500;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: actionColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: actionColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
