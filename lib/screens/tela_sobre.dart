import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('about_us_title'.tr()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: SelectableText(
              'about_us_body'.tr(),
              textAlign: TextAlign.justify,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
