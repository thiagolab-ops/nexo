import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_aprovacao_professor.dart';
import 'package:nexo/screens/tela_comentarios.dart';
import 'package:nexo/screens/tela_hub_detalhe.dart';
import 'package:nexo/screens/tela_perfil_usuario.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/feed_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tela_chat_mensagens.dart';

class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  late final NotificationService _notificationService;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _notificationService = context.read<NotificationService>();
    _notificationService.markAllNotificationsAsRead(_currentUserId);
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  void _handleNotificationTap(NotificationModel notification) async {
    await _notificationService.markNotificationAsRead(_currentUserId, notification.id);
    if (!mounted) return;
    
    switch (notification.sourceType) {
      case 'new_follower':
      case 'new_conexo':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => TelaPerfilUsuario(userId: notification.sourceId),
        ));
        break;
      case 'new_like':
      case 'new_comment':
        final post = await context.read<FeedService>().getPostById(notification.sourceId);
        if (post != null && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => TelaComentarios(post: post),
          ));
        }
        break;
      case 'dm_message':
        final chatRoom = await context.read<ChatService>().getChatRoomById(notification.sourceId);
        if (chatRoom != null && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => TelaChatMensagens(chatRoom: chatRoom),
          ));
        }
        break;
      case 'aula_convocada':
        if(notification.meetLink != null && notification.meetLink!.isNotEmpty) {
          _launchURL(notification.meetLink!);
        } else if (notification.relatedHubId != null) {
          final hub = await context.read<NexoHubService>().getHubById(notification.relatedHubId!);
          if (hub != null && mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TelaHubDetalhe(hub: hub),
            ));
          }
        }
        break;
      case 'professor_application':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const TelaAprovacaoProfessor(),
        ));
        break;
      default:
        print("Tipo de notificação não tratado: ${notification.sourceType}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getNotificationsStream(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma notificação ainda.'));
          }
          final notifications = snapshot.data!;
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: Icon(
                  notification.isRead ? Icons.notifications_none : Icons.notifications_active,
                  color: notification.isRead ? Colors.grey : Theme.of(context).primaryColor,
                ),
                title: Text(notification.text),
                subtitle: Text(notification.createdAt.toDate().toString()),
                onTap: () => _handleNotificationTap(notification),
              );
            },
          );
        },
      ),
    );
  }
}
