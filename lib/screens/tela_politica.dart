import 'package:flutter/material.dart';

class TelaPolitica extends StatelessWidget {
  const TelaPolitica({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Uso e Abuso'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '''
[PLACEHOLDER]

Nossa missão é criar um ambiente de estudo seguro e produtivo.

Tolerância Zero para Abuso:
O Nexo foi projetado para conectar estudantes, adolescentes e adultos. Levamos a segurança de menores de idade extremamente a sério.

Não será tolerado:
- Qualquer forma de assédio sexual ou solicitação inadequada.
- Bullying, intimidação ou linguagem tóxica.
- Discurso de ódio baseado em raça, etnia, religião, gênero, etc.
- Compartilhamento de material ilegal ou sexualmente explícito (motivo pelo qual o upload de fotos é restrito).

Denúncias:
Todas as denúncias em DMs (Mensagens Diretas) são levadas a sério. Nossa equipe de moderação revisará o conteúdo reportado.

Ações:
Violações resultarão em:
1. Advertência oficial.
2. Suspensão temporária da conta.
3. Banimento permanente e exclusão da conta.

...[TEXTO LEGAL COMPLETO A SER FORNECIDO PELO PROPRIETÁRIO DO PROJETO]...
          ''',
        ),
      ),
    );
  }
}
