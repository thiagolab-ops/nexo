import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/report_service.dart';
import 'package:nexo/utils.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class ForumWidget extends StatefulWidget {
  final CollectionReference topicsCollection;
  final UserModel currentUser;
  final bool enableCloseTopic;
  final bool enableBestAnswer;

  const ForumWidget({
    super.key,
    required this.topicsCollection,
    required this.currentUser,
    this.enableCloseTopic = false, 
    this.enableBestAnswer = false,
  });

  @override
  State<ForumWidget> createState() => _ForumWidgetState();
}

class _ForumWidgetState extends State<ForumWidget> {
  String? _selectedTopicId;
  String? _selectedTopicTitle;

  final TextEditingController _topicTitleController = TextEditingController();
  final TextEditingController _topicContentController = TextEditingController();
  final TextEditingController _topicTagsController = TextEditingController();
  final TextEditingController _replyContentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController(); 

  late final ReportService _reportService;
  String _searchTag = ''; 

  @override
  void initState() {
    super.initState();
    _reportService = context.read<ReportService>();
  }

  @override
  void dispose() {
    _topicTitleController.dispose();
    _topicContentController.dispose();
    _topicTagsController.dispose();
    _replyContentController.dispose();
    _searchController.dispose(); 
    super.dispose();
  }

  void _selectTopic(String topicId, String title) {
    setState(() {
      _selectedTopicId = topicId;
      _selectedTopicTitle = title;
    });
  }

  void _unselectTopic() {
    setState(() {
      _selectedTopicId = null;
      _selectedTopicTitle = null;
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Data indisponível';
    return DateFormat('dd/MM/yy HH:mm').format(timestamp.toDate());
  }

  void _showReportDialog({
    required String reportedUserId,
    required String contentId,
    required String contentType,
  }) {
    final reportController = TextEditingController();
    final reportOptions = ['Assédio', 'Discurso de Ódio', 'Spam', 'Outro'];
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Denunciar Conteúdo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  hint: const Text('Selecione um motivo'),
                  onChanged: (value) => setDialogState(() => selectedReason = value),
                  items: reportOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                ),
                if (selectedReason == 'Outro')
                  TextField(controller: reportController, decoration: const InputDecoration(labelText: 'Descreva')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: (selectedReason != null) ? () async {
                  final reason = (selectedReason == 'Outro') ? reportController.text.trim() : selectedReason!;
                  if (reason.isEmpty) return;
                  final report = ReportModel(
                    id: '',
                    reporterId: widget.currentUser.id,
                    reportedUserId: reportedUserId,
                    contentId: contentId,
                    contentType: contentType,
                    reason: reason,
                    createdAt: Timestamp.now(),
                  );
                  try {
                    await _reportService.submitReport(report);
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Denúncia enviada.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) showErrorDialog(context, 'Erro', e.toString());
                  }
                } : null,
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _selectedTopicId == null
        ? _buildTopicsListView()
        : _buildSingleTopicView(_selectedTopicId!, _selectedTopicTitle!);
  }

  Widget _buildTopicsListView() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildNewTopicForm(),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar por Tema (ex: inglês)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _searchTag = _searchController.text;
                  });
                },
              ),
            ),
            onSubmitted: (value) {
               setState(() {
                 _searchTag = value;
               });
            },
          ),
        ),
        Text(_searchTag.isEmpty ? "Tópicos Recentes" : "Resultados para: '$_searchTag'", 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildTopicsList(),
      ],
    );
  }

  Widget _buildNewTopicForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Iniciar um novo tópico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _topicTitleController,
              decoration: const InputDecoration(labelText: 'Título da sua dúvida'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicTagsController,
              decoration: const InputDecoration(labelText: 'Temas (ex: inglês, verbos, direito)', helperText: 'Separados por vírgula'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicContentController,
              decoration: const InputDecoration(labelText: 'Descreva sua dúvida em detalhes...'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addTopic,
              child: const Text('PUBLICAR TÓPICO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsList() {
    Query query;
    final tag = _searchTag.trim().toLowerCase();

    if (tag.isNotEmpty) {
      // --- CORREÇÃO DE SINTAXE AQUI ---
      // De: .where('tags', 'array-contains', tag)
      // Para: .where('tags', arrayContains: tag)
      query = widget.topicsCollection
          .where('tags', arrayContains: tag)
          .orderBy('createdAt', descending: true);
    } else {
      query = widget.topicsCollection.orderBy('createdAt', descending: true);
    }
    // --- FIM DA CORREÇÃO ---

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erro ao carregar tópicos. Você já fez o deploy dos índices do Firebase? (firebase deploy --only firestore:indexes)"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum tópico encontrado."));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final String authorUsername = data['authorUsername'] ?? 'Usuário Deletado';
            final String authorPhotoUrl = data['authorPhotoUrl'] ?? '';
            final bool isClosed = data['isClosed'] ?? false;
            final String? bestAnswerId = data['bestAnswerId'];
            final List<String> tags = List<String>.from(data['tags'] ?? []);

            return Card(
              color: isClosed ? Colors.grey[900] : null,
              child: ListTile(
                leading: UserAvatar(username: authorUsername, photoUrl: authorPhotoUrl, radius: 20),
                title: Text(data['title'] ?? 'Sem título', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                      child: Text(data['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text("Temas: ${tags.join(', ')}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                      ),
                    Text(
                      'Por: $authorUsername em ${_formatTimestamp(data['createdAt'])}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(bestAnswerId != null) const Icon(Icons.check_circle, color: Colors.greenAccent),
                    if(isClosed) const Icon(Icons.lock, color: Colors.grey),
                  ],
                ),
                onTap: () => _selectTopic(doc.id, data['title']),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSingleTopicView(String topicId, String topicTitle) {
    return Scaffold(
       appBar: AppBar(
        title: Text(topicTitle, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _unselectTopic,
        ),
       ),
       body: StreamBuilder<DocumentSnapshot>(
          stream: widget.topicsCollection.doc(topicId).snapshots(),
          builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (!snapshot.data!.exists) return const Center(child: Text("Tópico não encontrado."));
              
              final topicData = snapshot.data!.data() as Map<String, dynamic>;
              final authorUsername = topicData['authorUsername'] ?? 'Usuário Deletado';
              final authorPhotoUrl = topicData['authorPhotoUrl'] ?? '';
              final authorId = topicData['authorId'] ?? '';
              final bool isOwner = authorId == widget.currentUser.id;
              final bool isClosed = topicData['isClosed'] ?? false;
              final String? bestAnswerId = topicData['bestAnswerId'];
              final List<String> tags = List<String>.from(topicData['tags'] ?? []);

              return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      ListTile(
                                        leading: UserAvatar(username: authorUsername, photoUrl: authorPhotoUrl),
                                        title: Text(topicData['title'] ?? 'Sem título', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                        subtitle: Text('Por: $authorUsername\nEm: ${_formatTimestamp(topicData['createdAt'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'report') {
                                                _showReportDialog(reportedUserId: authorId, contentId: topicId, contentType: 'forum_topic');
                                            }
                                            if (value == 'close') {
                                                widget.topicsCollection.doc(topicId).update({'isClosed': true});
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            if (!isOwner)
                                              const PopupMenuItem(
                                                value: 'report',
                                                child: ListTile(leading: Icon(Icons.report_problem_outlined, color: Colors.yellowAccent), title: Text('Denunciar Tópico')),
                                              ),
                                            if (isOwner && !isClosed && widget.enableCloseTopic)
                                              const PopupMenuItem(
                                                value: 'close',
                                                child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Fechar Tópico')),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 20),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: Text(topicData['content'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
                                      ),
                                      if (tags.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                          child: Text("Temas: ${tags.join(', ')}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                                        ),
                                  ],
                              ),
                          ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Respostas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildRepliesList(topicId, isOwner, isClosed, bestAnswerId),
                      const SizedBox(height: 24),
                      if (!isClosed)
                        _buildReplyForm(topicId)
                      else 
                        const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("Este tópico foi fechado pelo autor.", style: TextStyle(color: Colors.yellowAccent)))),
                  ],
              );
          },
       ),
    );
  }
  
  Widget _buildRepliesList(String topicId, bool isTopicOwner, bool isTopicClosed, String? bestAnswerId) {
    return StreamBuilder<QuerySnapshot>(
        stream: widget.topicsCollection.doc(topicId).collection('replies').orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
             if (snapshot.hasError) return const Text("Erro ao carregar respostas.");
             if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
             if (snapshot.data!.docs.isEmpty) return const Center(child: Padding(
               padding: EdgeInsets.all(16.0),
               child: Text("Nenhuma resposta ainda. Seja o primeiro!"),
             ));

            return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final authorUsername = data['authorUsername'] ?? 'Usuário Deletado';
                    final authorPhotoUrl = data['authorPhotoUrl'] ?? '';
                    final authorId = data['authorId'] ?? '';
                    final bool isBestAnswer = doc.id == bestAnswerId;

                    return Card(
                        color: isBestAnswer ? Colors.green[900] : const Color(0xFF1F1F1F),
                        elevation: isBestAnswer ? 8 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isBestAnswer ? Colors.greenAccent : Colors.transparent, width: 2)
                        ),
                        child: ListTile(
                           leading: UserAvatar(username: authorUsername, photoUrl: authorPhotoUrl, radius: 18),
                           title: Text(data['content'] ?? ''),
                           subtitle: Text('Por: $authorUsername em ${_formatTimestamp(data['createdAt'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                           trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isBestAnswer) const Icon(Icons.check_circle, color: Colors.greenAccent),
                              if (widget.enableBestAnswer && isTopicOwner && !isTopicClosed && !isBestAnswer)
                                IconButton(
                                  icon: const Icon(Icons.check_box_outline_blank, color: Colors.greenAccent),
                                  tooltip: 'Marcar como Melhor Resposta',
                                  onPressed: () {
                                    widget.topicsCollection.doc(topicId).update({'bestAnswerId': doc.id});
                                  },
                                ),
                              if (authorId != widget.currentUser.id) 
                                IconButton(
                                  icon: const Icon(Icons.report_problem_outlined, color: Colors.yellowAccent, size: 20),
                                  tooltip: 'Denunciar Resposta',
                                  onPressed: () => _showReportDialog(
                                    reportedUserId: authorId,
                                    contentId: doc.id,
                                    contentType: 'forum_reply',
                                  ),
                                ),
                            ],
                           ),
                        ),
                    );
                },
            );
        },
    );
  }

  Widget _buildReplyForm(String topicId) {
      return Card(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                     const Text("Deixe uma resposta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 16),
                    TextField(
                        controller: _replyContentController,
                        decoration: const InputDecoration(labelText: 'Sua resposta...'),
                        maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: () => _addReply(topicId),
                        child: const Text('ENVIAR RESPOSTA'),
                    ),
                ],
            ),
        ),
      );
  }

  Future<void> _addTopic() async {
    if (_topicTitleController.text.isNotEmpty && _topicContentController.text.isNotEmpty) {
      
      final tags = _topicTagsController.text
          .split(',')
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toList();

      await widget.topicsCollection.add({
        'title': _topicTitleController.text,
        'content': _topicContentController.text,
        'tags': tags,
        'authorId': widget.currentUser.id,
        'authorUsername': widget.currentUser.username,
        'authorPhotoUrl': widget.currentUser.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'isClosed': false,
        'bestAnswerId': null,
      });
      
      _topicTitleController.clear();
      _topicContentController.clear();
      _topicTagsController.clear();
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tópico criado com sucesso!')));
      }
    }
  }
  
  Future<void> _addReply(String topicId) async {
      if(_replyContentController.text.isNotEmpty) {
          await widget.topicsCollection.doc(topicId).collection('replies').add({
              'content': _replyContentController.text,
              'authorId': widget.currentUser.id,
              'authorUsername': widget.currentUser.username,
              'authorPhotoUrl': widget.currentUser.photoUrl,
              'createdAt': FieldValue.serverTimestamp(),
          });
          _replyContentController.clear();
          if (mounted) {
             FocusScope.of(context).unfocus();
          }
      }
  }
}
