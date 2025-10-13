import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';

class TelaRecompensas extends StatelessWidget {
  const TelaRecompensas({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserModel?>();
    const int metaConvites = 50;

    if (userProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double progresso = userProfile.inviteCount / metaConvites;
    final String linkConvite = 'https://daxu.app/join?ref=${userProfile.username}';

    return Scaffold(
      appBar: AppBar(
        title: Text('rewards_title'.tr()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  'rewards_pageTitle'.tr(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'rewards_description'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                Text(
                  'rewards_yourGoal'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '${userProfile.inviteCount} / $metaConvites',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                Text('rewards_invitedUsers'.tr()),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progresso > 1.0 ? 1.0 : progresso,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'rewards_finalReward'.tr(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.workspace_premium, color: Colors.purple.shade300),
                          title: Text('rewards_premiumTitle'.tr()),
                          subtitle: Text('rewards_premiumSubtitle'.tr()),
                        ),
                        ListTile(
                          leading: const Icon(Icons.verified, color: Colors.blueAccent),
                          title: Text('rewards_badgeTitle'.tr()),
                          subtitle: Text('rewards_badgeSubtitle'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text('rewards_copyLinkButton'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: linkConvite));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('rewards_copyLinkSuccess'.tr()),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
