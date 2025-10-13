import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nexo/screens/tela_aprovacao_professor.dart';
import 'package:nexo/screens/tela_contato.dart';
import 'package:nexo/screens/tela_dashboard_professor.dart';
import 'package:nexo/screens/tela_moderacao.dart';
import 'package:nexo/screens/tela_nexogo_admin.dart';
import 'package:nexo/screens/tela_politica.dart';
import 'package:nexo/screens/tela_recompensas.dart';
import 'package:nexo/screens/tela_sobre.dart';
import 'package:nexo/screens/tela_termos.dart';
import 'package:nexo/services/theme_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/profile_service.dart';
import '../utils.dart';
import '../widgets/user_avatar.dart';
import 'tela_gerenciar_bloqueios.dart';
import 'package:provider/provider.dart';
import 'dart:js' as js;

class Language {
  final Locale locale;
  final String name;
  final String flag;
  Language(this.locale, this.name, this.flag);
}

class TelaPerfil extends StatefulWidget {
  final String userId;
  const TelaPerfil({super.key, required this.userId});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  late final ProfileService _profileService;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;

  String _originalUsername = '';
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isProcessingPayment = false;

  final List<Language> supportedLanguages = [
    Language(const Locale('pt'), 'Português', '🇧🇷'),
    Language(const Locale('en'), 'English', '🇺🇸'),
  ];

  @override
  void initState() {
    super.initState();
    _profileService = context.read<ProfileService>();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _interestsController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    super.dispose();
  }
  
  Future<void> _initiateCheckout(String priceId) async {
    setState(() => _isProcessingPayment = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('createCheckoutSession');
      
      final response = await callable.call<Map<String, dynamic>>({
        'priceId': priceId,
      });

      final sessionUrl = response.data['sessionUrl'];
      if (sessionUrl != null) {
        js.context.callMethod('open', [sessionUrl, '_self']);
      } else {
        throw Exception('URL da sessão de checkout não recebida.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        showErrorDialog(context, 'payment_processingError'.tr(), 'Código: ${e.code}\nMensagem: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'payment_unexpectedError'.tr(), e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image == null) return;
        final resizedImage = img.copyResize(image, width: 500);
        final jpgBytes = img.encodeJpg(resizedImage, quality: 85);
        await _profileService.uploadProfilePicture(uid: widget.userId, imageData: jpgBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('profile_photoSuccess'.tr()), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Erro no Upload', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final novoUsername = _usernameController.text.trim();
      if (novoUsername != _originalUsername) {
        final isUnique = await _profileService.isUsernameUnique(novoUsername);
        if (!isUnique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: Colors.redAccent, content: Text('profile_usernameInUse'.tr())),
            );
          }
          return;
        }
      }
      final interestsList = _interestsController.text.trim().split(',')
      .map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
      final dadosParaAtualizar = {
        'username': novoUsername,
        'bio': _bioController.text.trim(),
        'interests': interestsList,
      };
      await _profileService.updateUserProfile(widget.userId, dadosParaAtualizar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('profileUpdateSuccess'.tr())),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Erro ao Salvar', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareInviteLink(String username) {
    final String inviteLink = 'https://daxu.app/join?ref=$username';
    final String text = 'profile_inviteShareText'.tr(namedArgs: {'invite_link': inviteLink});
    Share.share(text, subject: 'profile_inviteShareSubject'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final currentLocale = context.locale;
    final currentLang = supportedLanguages.firstWhere(
      (lang) => lang.locale == currentLocale,
      orElse: () => supportedLanguages.first,
    );

    return StreamBuilder<UserModel?>(
      stream: _profileService.getUserProfileStream(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final userProfile = snapshot.data!;
        
        if (_originalUsername.isEmpty) {
          _usernameController.text = userProfile.username;
          _bioController.text = userProfile.bio;
          _interestsController.text = userProfile.interests.join(', ');
          _originalUsername = userProfile.username;
        }

        String subscriptionText;
        switch (userProfile.subscriptionStatus) {
          case SubscriptionStatus.adFree:
            subscriptionText = 'profile_subscriptionAdFree'.tr();
            break;
          case SubscriptionStatus.professor:
            subscriptionText = 'profile_subscriptionProfessor'.tr();
            break;
          default:
            subscriptionText = 'profile_subscriptionFree'.tr();
        }

        return Scaffold(
          appBar: AppBar(title: Text('editProfileTitle'.tr())),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              UserAvatar(
                                username: userProfile.username,
                                photoUrl: userProfile.photoUrl,
                                radius: 60,
                              ),
                              const CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.edit, size: 24, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (_isUploading) const CircularProgressIndicator(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (userProfile.role == 'super_admin') ...[
                       ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.amber),
                        title: Text('profile_approveTeachers'.tr()),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const TelaAprovacaoProfessor(),
                          ));
                        },
                      ),
                      const Divider(height: 24),
                    ],

                    if (userProfile.isPrivileged) ...[
                      ListTile(
                        leading: const Icon(Icons.dashboard_outlined),
                        title: Text('profile_myDashboard'.tr()),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const TelaDashboardProfessor(),
                          ));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: Text('profile_contentModeration'.tr()),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const TelaModeracao(),
                          ));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.video_library_outlined),
                        title: Text('profile_myDaxuGo'.tr()),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const TelaNexoGoAdmin(),
                          ));
                        },
                      ),
                      const Divider(height: 24),
                    ],

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(labelText: 'usernameLabel'.tr()),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _bioController,
                            decoration: InputDecoration(labelText: 'bioLabel'.tr()),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _interestsController,
                            decoration: InputDecoration(
                              labelText: 'profile_interestsLabel'.tr(),
                              helperText: 'profile_interestsHelper'.tr(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text('saveChangesButton'.tr()),
                        onPressed: _salvarAlteracoes,
                      ),
                    const Divider(height: 48),

                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                 ListTile(
                                  leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                                  title: Text('profile_accountStatus'.tr()),
                                  subtitle: Text(subscriptionText),
                                ),
                                if (userProfile.role == 'student')
                                   ListTile(
                                    leading: const Icon(Icons.school_outlined, color: Colors.greenAccent),
                                    title: Text('profile_wannaBeTeacher'.tr()),
                                    subtitle: Text('profile_wannaBeTeacherSubtitle'.tr()),
                                    onTap: _isProcessingPayment ? null : () => _initiateCheckout('price_1SEHBUQmCOX7rhgS4e52lP2c'),
                                  ),
                                if (userProfile.subscriptionStatus == SubscriptionStatus.free)
                                  ListTile(
                                    leading: const Icon(Icons.ads_click),
                                    title: Text('profile_premiumComingSoon'.tr()),
                                    subtitle: Text('profile_premiumSubtitle'.tr()),
                                    onTap: _isProcessingPayment ? null : () => _initiateCheckout('price_1SEHJXQmCOX7rhgSog6j9j4F'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_isProcessingPayment)
                          const CircularProgressIndicator(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // ## INÍCIO DO CÓDIGO RESTAURADO ##
                    ListTile(
                      leading: const Icon(Icons.military_tech_outlined, color: Colors.amberAccent),
                      title: Text('profile_rewards'.tr()),
                      subtitle: Text('profile_rewardsSubtitle'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaRecompensas(),
                        ));
                      },
                    ),

                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_outlined, color: Colors.lightBlueAccent),
                      title: Text('profile_inviteFriends'.tr()),
                      onTap: () => _shareInviteLink(userProfile.username),
                    ),

                    SwitchListTile(
                      title: Text('profile_darkMode'.tr()),
                      secondary: Icon(isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                      value: isDarkMode,
                      onChanged: (bool newValue) {
                        context.read<ThemeProvider>().toggleTheme(newValue);
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<Language>(
                      value: currentLang,
                      decoration: InputDecoration(
                        labelText: 'profile_appLanguage'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: supportedLanguages.map((Language lang) {
                        return DropdownMenuItem<Language>(
                          value: lang,
                          child: Text('${lang.flag} ${lang.name}'),
                        );
                      }).toList(),
                      onChanged: (Language? lang) {
                        if (lang != null) {
                          context.setLocale(lang.locale);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text('manageBlockedUsers'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaGerenciarBloqueios(),
                        ));
                      },
                    ),

                     ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('about_us_title'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaSobre(),
                        ));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.alternate_email_outlined),
                      title: Text('contact_us_title'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaContato(),
                        ));
                      },
                    ),
                     ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text('terms_of_use_title'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaTermos(),
                        ));
                      },
                    ),
                     ListTile(
                      leading: const Icon(Icons.policy_outlined),
                      title: Text('privacy_policy_title'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaPolitica(),
                        ));
                      },
                    ),
                    // ## FIM DO CÓDIGO RESTAURADO ##
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
