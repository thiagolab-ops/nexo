import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nexo/screens/tela_dashboard_professor.dart';
import 'package:nexo/screens/tela_moderacao.dart'; // Importando a nova tela
import '../models/models.dart';
import '../services/profile_service.dart';
import '../utils.dart';
import '../widgets/user_avatar.dart';
import 'tela_gerenciar_bloqueios.dart';

class TelaPerfil extends StatefulWidget {
  final String userId;
  const TelaPerfil({super.key, required this.userId});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class Language {
  final Locale locale;
  final String name;
  final String flag;
  Language(this.locale, this.name, this.flag);
}

class _TelaPerfilState extends State<TelaPerfil> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;
  
  String _originalUsername = '';
  bool _isSaving = false;
  bool _isUploading = false;
  
  final List<Language> supportedLanguages = [
    Language(const Locale('pt'), 'Português', '🇧🇷'),
    Language(const Locale('en'), 'English', '🇺🇸'),
  ];
  
  @override
  void initState() {
    super.initState();
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
            const SnackBar(content: Text('Foto de perfil atualizada!'), backgroundColor: Colors.green),
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
              const SnackBar(backgroundColor: Colors.redAccent, content: Text('Este @username já está em uso.')),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _profileService.getUserProfileStream(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final userProfile = snapshot.data!;
        
        // This ensures text fields are populated only once
        if (_originalUsername.isEmpty) {
          _usernameController.text = userProfile.username;
          _bioController.text = userProfile.bio;
          _interestsController.text = userProfile.interests.join(', ');
          _originalUsername = userProfile.username;
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
                    
                    // BOTÕES DE AÇÃO DO PROFESSOR
                    if (userProfile.role == 'professor') ...[
                      ListTile(
                        leading: const Icon(Icons.dashboard_outlined),
                        title: const Text('Meu Dashboard'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const TelaDashboardProfessor(),
                          ));
                        },
                      ),
                      // NOVO BOTÃO DE MODERAÇÃO
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: const Text('Moderação de Conteúdo'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const TelaModeracao(),
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
                            decoration: const InputDecoration(labelText: 'Interesses', helperText: 'Separe por vírgulas'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isSaving)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text('saveChangesButton'.tr()),
                        onPressed: _salvarAlteracoes,
                      ),
                    const Divider(height: 48),
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text('manageBlockedUsers'.tr()),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const TelaGerenciarBloqueios(),
                        ));
                      },
                    ),
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
