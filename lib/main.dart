import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexo/nexo_theme.dart'; 
import 'package:nexo/screens/tela_baralhos_lista.dart'; 
import 'package:nexo/screens/tela_daxu_chan.dart'; 
import 'package:nexo/screens/tela_notificacoes.dart';
import 'package:nexo/screens/tela_perfil.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/feed_service.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/mind_map_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/notification_service.dart';
import 'package:nexo/services/quiz_service.dart';
import 'package:nexo/services/report_service.dart';
import 'package:nexo/services/theme_provider.dart'; 
import 'package:provider/provider.dart';
import 'package:nexo/screens/tela_feed.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'services/profile_service.dart';
import 'services/nexo_pad_service.dart';
import 'screens/tela_criar_post.dart';
import 'screens/tela_hubs_lista.dart';
import 'screens/tela_nexo_pad_lista.dart';
import 'screens/tela_play_lista.dart'; 
import 'screens/tela_social_nova.dart'; 
import 'screens/tela_nexo_pad.dart';
import 'widgets/user_avatar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'), Locale('pt'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('pt'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<User?>(
      create: (_) => FirebaseAuth.instance.authStateChanges(),
      initialData: null,
      child: Consumer<User?>(
        builder: (context, user, _) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              Provider<ProfileService>(create: (_) => ProfileService()),
              Provider<NotificationService>(create: (_) => NotificationService()),
              Provider<NexoPadService>(create: (_) => NexoPadService()),
              Provider<FirestoreService>(create: (_) => FirestoreService()),
              Provider<NexoHubService>(create: (_) => NexoHubService()),
              Provider<ChatService>(create: (_) => ChatService()),
              Provider<FeedService>(create: (_) => FeedService()),
              Provider<QuizService>(create: (_) => QuizService()),
              Provider<ReportService>(create: (_) => ReportService()),
              Provider<MindMapService>(create: (_) => MindMapService()),
              
              if (user != null)
                StreamProvider<UserModel?>.value(
                  value: ProfileService().getUserProfileStream(user.uid),
                  initialData: null,
                )
            ],
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  title: 'Daxu', 
                  theme: NexoTheme.light,
                  darkTheme: NexoTheme.dark,
                  themeMode: themeProvider.themeMode,
                  home: const AuthGate(),
                  debugShowCheckedModeBanner: false,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAtual = 0;
  
  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();
    _telas = [
      TelaBaralhosLista(showNewDeckDialog: _mostrarDialogoNovoBaralho), 
      const TelaHubsLista(),
      const TelaNexoPadLista(),
      const TelaDaxuChan(), 
      const TelaFeed(),
      const TelaPlayLista(),
      const TelaSocialNova(), 
    ];
  }

  void _mostrarDialogoNovoBaralho({Baralho? baralhoExistente}) {
    // ... (código do diálogo sem mudanças)
    final nomeController = TextEditingController(text: baralhoExistente?.nome);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(baralhoExistente == null ? 'newDeckDialogTitle'.tr() : 'Editar Nome'),
          content: TextField(
            controller: nomeController,
            autofocus: true,
            decoration: InputDecoration(hintText: 'newDeckDialogHint'.tr()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('cancelButton'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                if (nome.isNotEmpty) {
                  final firestoreService = context.read<FirestoreService>();
                  final userId = FirebaseAuth.instance.currentUser!.uid;
                  if (baralhoExistente != null) {
                    await firestoreService.updateBaralho(userId, baralhoExistente.id!, nome);
                  } else {
                    final novoBaralho = Baralho(nome: nome, ownerId: userId);
                    await firestoreService.addBaralho(novoBaralho, userId);
                  }
                  if (mounted) Navigator.of(dialogContext).pop();
                }
              },
              child: Text(baralhoExistente == null ? 'addButton'.tr() : 'saveButton'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showCreateHubDialog() {
    // ... (código do diálogo sem mudanças)
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final hubService = context.read<NexoHubService>();
        
        return AlertDialog(
          title: const Text('Criar Novo Hub'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome do Hub'),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'O nome é obrigatório.' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descrição (Opcional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await hubService.createHub(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hub criado com sucesso!'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, UserModel userProfile) {
    // ... (código do FAB sem mudanças)
    switch (_indiceAtual) {
      case 0: 
        return FloatingActionButton(
          heroTag: 'add_deck',
          onPressed: () => _mostrarDialogoNovoBaralho(),
          tooltip: 'addDeckTooltip'.tr(),
          child: const Icon(Icons.add),
        );
        
      case 1: 
        return FloatingActionButton(
          heroTag: 'add_hub',
          onPressed: _showCreateHubDialog,
          tooltip: 'Criar Hub',
          child: const Icon(Icons.add),
        );

      case 2: 
        return FloatingActionButton(
          heroTag: 'add_document',
          onPressed: () async {
            final nexoPadService = context.read<NexoPadService>();
            final newDocument = await nexoPadService.createNewDocument();
            if (mounted) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => TelaNexoPad(document: newDocument),
              ));
            }
          },
          tooltip: 'Novo Documento',
          child: const Icon(Icons.add),
        );
      case 4: 
        if (userProfile.role == 'professor') {
          return FloatingActionButton(
            heroTag: 'add_post',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const TelaCriarPost(),
                fullscreenDialog: true,
              ));
            },
            tooltip: 'Criar Post',
            child: const Icon(Icons.add),
          );
        }
        return null; 
      default: 
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserModel?>(context);

    if (userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        // --- LOGO ATUALIZADO PARA MAIÚSCULO ---
        title: Text('DAXU', style: GoogleFonts.pressStart2p(fontSize: 20)),
        actions: [
          Builder(
            builder: (context) {
              final unreadCount = userProfile.unreadNotificationCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Notificações',
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const TelaNotificacoes(),
                      ));
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        height: 10, width: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            }
          ),
          IconButton(
            tooltip: 'editProfileTooltip'.tr(),
            onPressed: () {
               Navigator.of(context).push(MaterialPageRoute(
                 builder: (context) => TelaPerfil(userId: userProfile.id),
               ));
            },
            icon: UserAvatar(
              key: ValueKey(userProfile.photoUrl), 
              username: userProfile.username,
              photoUrl: userProfile.photoUrl,
              radius: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'logoutTooltip'.tr(),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _indiceAtual,
        children: _telas,
      ),
      floatingActionButton: _buildFloatingActionButton(context, userProfile), 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: (indice) => setState(() => _indiceAtual = indice),
        type: BottomNavigationBarType.fixed,
        items: [
          // --- ATUALIZADO PARA 7 ABAS COM AS LABELS NOVAS ---
          BottomNavigationBarItem(icon: const Icon(Icons.style), label: 'card_label'.tr()), // Daxu Card
          BottomNavigationBarItem(icon: const Icon(Icons.group_work), label: 'hub_label'.tr()), // Daxu Hub
          BottomNavigationBarItem(icon: const Icon(Icons.edit_document), label: 'pad_label'.tr()), // Daxu Pad
          BottomNavigationBarItem(icon: const Icon(Icons.forum_outlined), label: 'chan_label'.tr()), // Daxu Chan
          BottomNavigationBarItem(icon: const Icon(Icons.dynamic_feed), label: 'feed_label'.tr()), // Daxu Feed
          BottomNavigationBarItem(icon: const Icon(Icons.videogame_asset_outlined), label: 'play_label'.tr()), // Daxu Play
          BottomNavigationBarItem(icon: const Icon(Icons.people_alt_outlined), label: 'social_label'.tr()), // Social
        ],
      ),
    );
  }
}
