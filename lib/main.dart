import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexo/nexo_theme.dart';
import 'package:nexo/screens/tela_baralhos_lista.dart';
import 'package:nexo/screens/tela_daxu_chan.dart';
import 'package:nexo/screens/tela_notificacoes.dart';
import 'package:nexo/screens/tela_payment_cancel.dart';
import 'package:nexo/screens/tela_payment_success.dart';
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
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'dart:io' show Platform;

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

// Constante para ligar/desligar o uso dos emuladores
const bool USE_EMULATOR = true;

Future<void> _connectToEmulators() async {
  final String host = kIsWeb ? 'localhost' : Platform.isAndroid ? '10.0.2.2' : 'localhost';

  try {
    print('--- USANDO EMULADORES LOCAIS ---');
    
    // Conecta ao emulador do Firestore
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    print('[OK] Firestore Emulator -> $host:8080');

    // Conecta ao emulador do Functions
    FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(host, 5001);
    print('[OK] Functions Emulator -> $host:5001');

    // Conecta ao emulador do Authentication
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    print('[OK] Auth Emulator -> $host:9099');
    
    print('--- CONEXÃO COM EMULADORES ESTABELECIDA ---');
  } catch (e) {
    print('!!! ERRO AO CONECTAR AOS EMULADORES: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }
  
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  if (kDebugMode && USE_EMULATOR) {
    await _connectToEmulators();
  }
  
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

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
        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: Consumer<User?>(
        builder: (context, user, _) {
          return StreamProvider<UserModel?>.value(
            value: user != null ? ProfileService().getUserProfileStream(user.uid) : Stream.value(null),
            initialData: null,
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  title: 'DAXU',
                  theme: NexoTheme.light,
                  darkTheme: NexoTheme.dark,
                  themeMode: themeProvider.themeMode,
                  debugShowCheckedModeBanner: false,
                  // ## AQUI ESTÁ A MUDANÇA: 'home' foi trocado por 'initialRoute' e 'routes' ##
                  initialRoute: '/',
                  routes: {
                    '/': (context) => const AuthGate(),
                    '/payment-success': (context) => const TelaPaymentSuccess(),
                    '/payment-cancel': (context) => const TelaPaymentCancel(),
                  },
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

  @override
  void initState() {
    super.initState();
    _checkCustomClaims();
  }
  
  void _checkCustomClaims() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idTokenResult = await user.getIdTokenResult(true); 
      if(kDebugMode) {
        print('--- [CUSTOM CLAIMS DEBUG] ---');
        print('Claims do Token: ${idTokenResult.claims}');
        print('-----------------------------');
      }
    }
  }

  void _mostrarDialogoNovoBaralho({Baralho? baralhoExistente}) {
    final nomeController = TextEditingController(text: baralhoExistente?.nome);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(baralhoExistente == null ? 'newDeckDialogTitle'.tr() : 'main_editDeckName'.tr()),
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
                    final novoBaralho = Baralho(id: '', nome: nome, ownerId: userId);
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
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final hubService = context.read<NexoHubService>();
        
        return AlertDialog(
          title: Text('main_createNewHub'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: 'main_hubName'.tr()),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'main_hubNameRequired'.tr() : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'main_hubDescription'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('cancelButton'.tr()),
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
                      SnackBar(content: Text('main_hubCreateSuccess'.tr()), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: Text('hubDetail_createButton'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, UserModel userProfile, List<Widget> telas) {
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
          tooltip: 'main_createHubTooltip'.tr(),
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
          tooltip: 'main_newDocumentTooltip'.tr(),
          child: const Icon(Icons.add),
        );
      case 4:
        if (userProfile.isPrivileged) {
          return FloatingActionButton(
            heroTag: 'add_post',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const TelaCriarPost(),
                fullscreenDialog: true,
              ));
            },
            tooltip: 'main_createPostTooltip'.tr(),
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

    final List<Widget> telas = [
      TelaBaralhosLista(showNewDeckDialog: _mostrarDialogoNovoBaralho),
      TelaHubsLista(),
      TelaNexoPadLista(),
      TelaDaxuChan(),
      TelaFeed(),
      TelaPlayLista(),
      TelaSocialNova(),
    ];

    if (userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
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
                    tooltip: 'main_notificationsTooltip'.tr(),
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
        children: telas,
      ),
      floatingActionButton: _buildFloatingActionButton(context, userProfile, telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: (indice) => setState(() => _indiceAtual = indice),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.style), label: 'card_label'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.group_work), label: 'hub_label'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.edit_document), label: 'pad_label'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.forum_outlined), label: 'chan_label'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.dynamic_feed), label: 'feed_label'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.videogame_asset_outlined), label: 'play_label'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.people_alt_outlined), label: 'social_label'.tr()),
        ],
      ),
    );
  }
}
