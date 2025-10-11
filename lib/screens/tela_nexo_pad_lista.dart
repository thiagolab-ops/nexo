import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/nexo_pad_service.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class TelaNexoPadLista extends StatefulWidget {
  const TelaNexoPadLista({super.key});

  @override
  State<TelaNexoPadLista> createState() => _TelaNexoPadListaState();
}

class _TelaNexoPadListaState extends State<TelaNexoPadLista> {
  late final NexoPadService _nexoPadService;
  late final NexoHubService _hubService;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _nexoPadService = context.read<NexoPadService>();
    _hubService = context.read<NexoHubService>();
  }
  
  void _deleteDocument(NexoPadDocument doc) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('pad_deleteTitle'.tr()),
        content: Text('pad_deleteConfirmation'.tr(namedArgs: {'docTitle': doc.title})),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('cancelButton'.tr())),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('hubDetail_deleteButton'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _nexoPadService.deleteDocument(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('pad_deleteSuccess'.tr(namedArgs: {'docTitle': doc.title})), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _showShareDocToHubDialog(NexoPadDocument doc) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<NexoHub>>(
        stream: _hubService.getHubsForCurrentUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Dialog(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
          }
          if (snapshot.data!.isEmpty) {
            return AlertDialog(
              title: Text('pad_shareToHubTitle'.tr()),
              content: Text('pad_shareWarningNoHubs'.tr()),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('pad_okButton'.tr()))],
            );
          }
          final hubs = snapshot.data!;
          return AlertDialog(
            title: Text('pad_shareWhichHubTitle'.tr()),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hubs.length,
                itemBuilder: (context, index) {
                  final hub = hubs[index];
                  return ListTile(
                    title: Text(hub.name),
                    onTap: () async {
                      Navigator.of(context).pop(); // Fecha o diálogo
                      await _hubService.createSharedDocumentInHub(
                        hubId: hub.id,
                        title: doc.title,
                        ownerId: _currentUserId,
                        initialContentJson: doc.contentJson,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('pad_shareSuccess'.tr(namedArgs: {'hubName': hub.name})), backgroundColor: Colors.green),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<NexoPadDocument>>(
        stream: _nexoPadService.getDocumentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('pad_genericError'.tr(namedArgs: {'error': snapshot.error.toString()})));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('pad_emptyState'.tr()));
          }
          final documents = snapshot.data!;
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              final timeAgoString = timeago.format(doc.lastEdited.toDate(), locale: context.locale.toStringWithSeparator(separator: '_'));
              return ListTile(
                leading: const Icon(Icons.edit_document),
                title: Text(doc.title),
                subtitle: Text('pad_edited'.tr(namedArgs: {'timeago': timeAgoString})),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'share') {
                      _showShareDocToHubDialog(doc);
                    } else if (value == 'delete') {
                      _deleteDocument(doc);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(leading: const Icon(Icons.share), title: Text('pad_shareAction'.tr())),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(leading: const Icon(Icons.delete, color: Colors.redAccent), title: Text('hubDetail_deleteButton'.tr(), style: const TextStyle(color: Colors.redAccent))),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaNexoPad(document: doc),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
