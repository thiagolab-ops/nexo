import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Certifique-se de que 'package:nexo/models/models.dart' importa Curso, Lesson e UserModel
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_curso_player.dart';
import 'package:nexo/services/chat_service.dart'; // Mantido, mas não usado diretamente aqui
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/profile_service.dart'; // Mantido, mas não usado diretamente aqui
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'tela_curso_player_test.mocks.dart';

// Mock simples do seu modelo de curso para usar nos testes
class MockCurso extends Mock implements Curso {}
class MockLesson extends Mock implements Lesson {}
class MockUserModel extends Mock implements UserModel {}

// Anotação que diz ao build_runner para criar um mock da classe FirestoreService
// Adicione ProfileService e ChatService se você precisar de mocks para eles no futuro
@GenerateMocks([FirestoreService, ProfileService, ChatService])
void main() {
  // Use um nome mais descritivo para o mock do curso
  late MockCurso mockCursoInstance;
  late MockUserModel mockProfProfileInstance;

  late MockFirestoreService mockFirestoreService;
  // late MockProfileService mockProfileService; // Exemplo de mock adicional
  // late MockChatService mockChatService; // Exemplo de mock adicional

  // Configura os mocks para Firebase Core antes de todos os testes
  // Agora dentro de setUpAll, para garantir que as mocks existam antes de qualquer Firebase.initializeApp
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocksHandler(); // Define o mock handler uma vez
  });

  setUp(() {
    // Inicializa uma nova instância do mock do serviço para cada teste
    mockFirestoreService = MockFirestoreService();
    // mockProfileService = MockProfileService();
    // mockChatService = MockChatService();

    // Configura os mocks para os modelos
    mockCursoInstance = MockCurso();
    when(mockCursoInstance.id).thenReturn('1');
    when(mockCursoInstance.ownerId).thenReturn('prof1');
    when(mockCursoInstance.title).thenReturn('Test Course');
    when(mockCursoInstance.description).thenReturn('Desc');
    when(mockCursoInstance.createdAt).thenReturn(Timestamp.now());
    when(mockCursoInstance.ratings).thenReturn({}); // Assegura que ratings existe

    mockProfProfileInstance = MockUserModel();
    when(mockProfProfileInstance.id).thenReturn('prof1');
    when(mockProfProfileInstance.username).thenReturn('prof');
    when(mockProfProfileInstance.email).thenReturn('prof@example.com');
    when(mockProfProfileInstance.bio).thenReturn('bio');
    when(mockProfProfileInstance.photoUrl).thenReturn('');
    when(mockProfProfileInstance.createdAt).thenReturn(Timestamp.now());
    when(mockProfProfileInstance.lastStudyDate).thenReturn(Timestamp.now());
  });

  testWidgets('TelaCursoPlayer deve construir sem erros com mock service', (WidgetTester tester) async {
    // Inicializa o Firebase no contexto do teste
    await Firebase.initializeApp();

    // Configura o comportamento dos métodos mockados
    when(mockFirestoreService.streamLessons(any, any))
        .thenAnswer((_) => Stream.value(<Lesson>[])); // Retorna um stream vazio de Lessons
    
    // Mock para getCursoStream retornar um DocumentSnapshot mockado
    when(mockFirestoreService.getCursoStream(any, any))
        .thenAnswer((_) => Stream.value(MockDocumentSnapshot(mockCursoInstance)));

    // Simula um usuário logado para FirebaseAuth
    final mockFirebaseAuth = MockFirebaseAuth(mockUser: MockUser(uid: 'testUserId'));
    when(mockFirebaseAuth.currentUser).thenReturn(MockUser(uid: 'testUserId'));


    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FirestoreService>.value(value: mockFirestoreService),
          Provider<UserModel?>.value(value: mockProfProfileInstance), // Usando a instância mockada
          // Se precisar de auth para outros serviços:
          // Provider<FirebaseAuth>.value(value: mockFirebaseAuth),
        ],
        child: MaterialApp(
          home: TelaCursoPlayer(
            curso: mockCursoInstance, // Usando a instância mockada
            profProfile: mockProfProfileInstance, // Usando a instância mockada
            firestoreService: mockFirestoreService,
          ),
        ),
      ),
    );

    // Verifica se o widget foi construído
    expect(find.byType(TelaCursoPlayer), findsOneWidget);
    // Verifica se nenhuma exceção foi lançada durante a renderização
    expect(tester.takeException(), isNull);
  });
}

// Handler de mocks para Firebase Core.
// Agora é uma função separada para ser chamada em setUpAll
void setupFirebaseCoreMocksHandler() {
  TestDefaultBinaryMessenger.instance.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_core'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'Firebase#initializeCore') {
        return [
          {
            'name': defaultFirebaseAppName,
            'options': {
              'apiKey': 'mock-api-key',
              'authDomain': 'mock-auth-domain',
              'projectId': 'mock-project-id',
              'storageBucket': 'mock-storage-bucket',
              'messagingSenderId': 'mock-sender-id',
              'appId': 'mock-app-id',
            },
            'pluginConstants': {},
          }
        ];
      }
      if (methodCall.method == 'Firebase#app') {
        return {'name': defaultFirebaseAppName, 'options': {}, 'pluginConstants': {}};
      }
      return null;
    },
  );
}


// Classe para mockar o DocumentSnapshot<Curso>
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Curso> {
  final Curso _mockCursoData;

  MockDocumentSnapshot(this._mockCursoData); // Construtor para receber a instância do Curso

  @override
  bool get exists => true;

  @override
  Curso? data() => _mockCursoData;

  // Implementações adicionais para evitar erros se outros getters/métodos forem chamados
  @override
  String get id => 'mockDocumentId';
  @override
  DocumentReference<Curso> get reference => throw UnimplementedError('MockDocumentSnapshot.reference not implemented');
  @override
  SnapshotMetadata get metadata => throw UnimplementedError('MockDocumentSnapshot.metadata not implemented');
  @override
  dynamic operator [](Object field) => throw UnimplementedError('MockDocumentSnapshot.[] not implemented');
  @override
  dynamic get(Object field) => throw UnimplementedError('MockDocumentSnapshot.get not implemented');
}
