import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TelaPaymentSuccess extends StatelessWidget {
  const TelaPaymentSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('payment_successTitle'.tr()),
        automaticallyImplyLeading: false, // Remove o botão de voltar padrão
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'payment_successTitle'.tr(),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'payment_successMessage'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Retorna para a primeira tela da pilha de navegação (TelaPrincipal)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text('payment_backToProfile'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
