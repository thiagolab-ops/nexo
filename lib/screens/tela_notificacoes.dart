import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/screens/tela_comentarios.dart';
import 'package:nexo/screens/tela_perfil_usuario.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/feed_service.dart';
import 'package:nexo/services/notification_service.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  _TelaNotificacoesState createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  late final NotificationService _notificationService;
  late final ChatService _chatService;
  late final FeedService _feedService;
  bool _didMarkAsRead = false; // Trava para rodar a função só uma vez

  @override
  void initState() {
    super.initState();
    _notificationService = context.read<NotificationService>();
    _chatService = context.read<ChatService>();
    _feedService = context.read<FeedService>();
  }

  Future<void> _handleNotificationTap(String currentUserId, NotificationModel notification) async {
    // Esta função agora só precisa se preocupar com a navegação.
    // A marcação individual ainda ocorre caso o usuário clique antes da marcação em lote terminar.
    if (!notification.isRead) {
      _notificationService.markNotificationAsRead(currentUserId, notification.id);
    }

    switch (notification.sourceType) {
      case 'new_follower':
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => TelaPerfilUsuario(userId: notification.sourceId)),
          );
        }
        break;

      case 'new_dm':
        final chatRoom = await _chatService.getChatRoomById(notification.sourceId);
        if (chatRoom != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: chatRoom)),
          );
        }
        break;
      
      case 'new_comment':
      case 'new_like':
        final post = await _feedService.getPostById(notification.sourceId);
        if (post != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => TelaComentarios(post: post)),
          );
        }
        break;
        
      case 'aula_convocada':
        if (notification.meetLink != null && notification.meetLink!.isNotEmpty) {
          final uri = Uri.tryParse(notification.meetLink!);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserModel?>(context);
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Usuário não encontrado.")));
    }

    // --- CORREÇÃO DO SINO VERMELHO ---
    // Assim que a tela é construída, chama a função de marcar tudo como lido.
    // A trava _didMarkAsRead impede que isso rode de novo se a tela for reconstruída.
    if (!_didMarkAsRead) {
      _notificationService.markAllNotificationsAsRead(currentUser.id);
      _didMarkAsRead = true;
    }
    // --- FIM DA CORREÇÃO ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getNotificationsStream(currentUser.id),
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
                // O ícone agora reflete o estado vindo do Firestore (que será atualizado rapidamente)
                leading: Icon(
                  notification.isRead ? Icons.notifications_none : Icons.notifications_active,
                  color: notification.isRead ? Colors.grey : Colors.lightBlueAccent,
                ),
                title: Text(notification.text),
                subtitle: Text(timeago.format(notification.createdAt.toDate(), locale: 'pt_BR')),
                onTap: () => _handleNotificationTap(currentUser.id, notification),
              );
            },
          );
        },
      ),
    );
  }
}
