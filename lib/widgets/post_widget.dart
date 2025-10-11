import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
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
    final reasons = ['post_reportReasonSpam', 'post_reportReasonHate', 'post_reportReasonHarassment', 'post_reportReasonOther'];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('post_reportTitle'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('post_reportReasonPrompt'.tr()),
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason.tr()),
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
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancelButton'.tr())),
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
                      reason: selectedReason!.tr(), // Salva a razão já traduzida
                      createdAt: Timestamp.now(),
                    );
                    
                    try {
                      await _reportService.submitReport(report);
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text('post_reportSuccess'.tr()), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                        navigator.pop();
                        showErrorDialog(context, 'post_reportErrorTitle'.tr(), 'post_reportErrorBody'.tr());
                    }
                  },
                  child: Text('post_reportSubmitButton'.tr()),
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
    final textToShare = 'post_shareText'.tr(namedArgs: {
      'username': widget.post.authorUsername,
      'postText': widget.post.text,
    });
    Share.share(textToShare, subject: 'post_shareSubject'.tr(namedArgs: {'username': widget.post.authorUsername}));
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
                        timeago.format(widget.post.createdAt.toDate(), locale: context.locale.toStringWithSeparator(separator: '_')),
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
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Text('post_reportAction'.tr()),
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
                  label: 'post_shareAction'.tr(),
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
