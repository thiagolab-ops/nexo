import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TelaTermos extends StatelessWidget {
  const TelaTermos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('terms_of_use_title'.tr()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: SelectableText(
              'terms_of_use_body'.tr(),
              textAlign: TextAlign.justify,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
