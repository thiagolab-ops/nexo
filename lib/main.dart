import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexo/screens/tela_baralhos_lista.dart'; 
import 'package:nexo/screens/tela_notificacoes.dart';
import 'package:nexo/screens/tela_perfil.dart';
import 'package:nexo/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:nexo/screens/tela_feed.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'services/profile_service.dart';
import 'screens/tela_criar_post.dart';
import 'screens/tela_hubs_lista.dart';
import 'screens/tela_nexo_pad_lista.dart';
import 'screens/tela_social.dart';
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
    // CORREÇÃO: Usando MultiProvider para injetar todos os serviços necessários
    // e o perfil do usuário na árvore de widgets.
    return MultiProvider(
      providers: [
        Provider<ProfileService>(create: (_) => ProfileService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        // Disponibiliza o estado de autenticação do usuário
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        title: 'Nexo',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.blueAccent,
          textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.lightBlueAccent,
            foregroundColor: Colors.white,
          ),
        ),
        home: const AuthGate(),
        debugShowCheckedModeBanner: false,
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
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  
  final List<Widget> _telas = [
    const TelaBaralhosLista(),
    const TelaHubsLista(),
    const TelaNexoPadLista(),
    const TelaSocial(),
    const TelaFeed(),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: context.read<ProfileService>().getUserProfileStream(_userId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final userProfile = userSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('NEXO', style: GoogleFonts.pressStart2p(fontSize: 20)),
            actions: [
              // O novo widget do sino de notificações
              StreamBuilder<int>(
                stream: context.read<NotificationService>().getUnreadNotificationCountStream(_userId),
                builder: (context, notificationSnapshot) {
                  final unreadCount = notificationSnapshot.data ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none),
                        tooltip: 'Notificações',
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            // Passando o perfil do usuário para a tela de notificações
                            builder: (context) => Provider.value(
                              value: userProfile,
                              child: const TelaNotificacoes(),
                            ),
                          ));
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            height: 10,
                            width: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
          floatingActionButton: (userProfile.role == 'professor')
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const TelaCriarPost(),
                      fullscreenDialog: true,
                    ));
                  },
                  tooltip: 'Criar Post',
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _indiceAtual,
            onTap: (indice) => setState(() => _indiceAtual = indice),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.style), label: 'decks_label'.tr()),
              BottomNavigationBarItem(icon: const Icon(Icons.group_work), label: 'hubs_label'.tr()),
              BottomNavigationBarItem(icon: const Icon(Icons.edit_document), label: 'nexopad_label'.tr()),
              BottomNavigationBarItem(icon: const Icon(Icons.people_alt), label: 'social_label'.tr()),
              BottomNavigationBarItem(icon: const Icon(Icons.dynamic_feed), label: 'feed_label'.tr()),
            ],
          ),
        );
      },
    );
  }
}
