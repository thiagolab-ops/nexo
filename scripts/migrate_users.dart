import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Importamos as opções do nosso próprio app para que o script saiba a qual projeto se conectar.
import '../lib/firebase_options.dart';

Future<void> main() async {
  print('Iniciando script de migração...');
  
  // Inicializa a conexão com o Firebase usando as credenciais do seu app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final usersRef = firestore.collection('users');
  int updatedCount = 0;

  try {
    print('Buscando todos os usuários...');
    final querySnapshot = await usersRef.get();
    
    if (querySnapshot.docs.isEmpty) {
      print('Nenhum usuário encontrado. Nada a fazer.');
      return;
    }

    print('Encontrados ${querySnapshot.docs.length} usuários. Verificando...');

    // Usamos um batch para fazer todas as atualizações de uma só vez (mais eficiente)
    final batch = firestore.batch();

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      // Verifica se o campo 'hasCompletedOnboarding' NÃO existe
      if (!data.containsKey('hasCompletedOnboarding')) {
        print('Atualizando usuário: ${doc.id} (${data['username']})');
        // Adiciona a operação de atualização ao batch
        batch.update(doc.reference, {'hasCompletedOnboarding': true});
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      print('\nEncontrados $updatedCount usuários antigos. Salvando atualizações...');
      await batch.commit();
      print('Migração concluída com sucesso! $updatedCount perfis foram atualizados.');
    } else {
      print('\nNenhum usuário precisava de atualização. Tudo certo!');
    }

  } catch (e) {
    print('Ocorreu um erro durante a migração: $e');
  }
}
