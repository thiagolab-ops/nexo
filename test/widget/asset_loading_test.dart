import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Garante que os bindings do Flutter estejam prontos antes do teste.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste de Regressão: O asset do Mapa Mental deve carregar com sucesso', () async {
    // Tenta carregar o conteúdo do arquivo HTML como uma String.
    // Se o arquivo estiver faltando ou o pubspec.yaml estiver incorreto,
    // esta linha irá lançar uma exceção e o teste falhará.
    try {
      final String htmlContent = await rootBundle.loadString('assets/mind_map/index.html');
      
      // Verifica se o conteúdo não está vazio e contém uma tag HTML esperada.
      expect(htmlContent.isNotEmpty, isTrue);
      expect(htmlContent.contains('</html>'), isTrue);

    } catch (e) {
      // Se qualquer erro ocorrer, força o teste a falhar com uma mensagem clara.
      fail('Falha ao carregar o asset do Mapa Mental: $e');
    }
  });
}
