import 'package:flutter/material.dart';

class TelaTermos extends StatelessWidget {
  const TelaTermos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos e Condições'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '''
[PLACEHOLDER]

Bem-vindo ao Nexo!

Ao usar nosso aplicativo, você concorda com estes termos. Por favor, leia-os com atenção.

1. Uso da Plataforma
Você concorda em usar o Nexo de forma responsável e ética.

2. Conteúdo do Usuário
Você é responsável por todo o conteúdo que posta. Não permitimos discurso de ódio, assédio, ou material ilegal.

3. Moderação
Reservamo-nos o direito de remover qualquer conteúdo ou usuário que viole nossos termos, a nosso exclusivo critério.

...[TEXTO LEGAL COMPLETO A SER FORNECIDO PELO PROPRIETÁRIO DO PROJETO]...
          ''',
        ),
      ),
    );
  }
}
