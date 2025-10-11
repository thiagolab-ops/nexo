import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chats_lista.dart';
import '../models/models.dart';
import '../services/nexo_hub_service.dart';
import '../services/profile_service.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/user_list_view.dart';
import 'package:provider/provider.dart';

class TelaSocialNova extends StatefulWidget {
  const TelaSocialNova({super.key});

  @override
  State<TelaSocialNova> createState() => _TelaSocialNovaState();
}

class _TelaSocialNovaState extends State<TelaSocialNova> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ProfileService _profileService;
  late final NexoHubService _hubService;
  final _searchController = TextEditingController();
  Future<List<UserModel>>? _searchResultsFuture;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _profileService = context.read<ProfileService>();
    _hubService = context.read<NexoHubService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  void _searchUsers() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        _searchResultsFuture = _profileService.searchUsersByUsername(
          query: query,
          currentUserId: _currentUserId,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserProfile = Provider.of<UserModel?>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'social_tabChats'.tr()),
            Tab(text: 'social_tabFollowers'.tr()),
            Tab(text: 'social_tabFollowing'.tr()),
            Tab(text: 'social_tabHubInvites'.tr()),
            Tab(text: 'social_tabSearch'.tr()),
          ],
        ),
      ),
      body: currentUserProfile == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                const TelaChatsLista(),
                UserListView(userIds: currentUserProfile.followerIds, currentUserProfile: currentUserProfile),
                UserListView(userIds: currentUserProfile.followingIds, currentUserProfile: currentUserProfile),
                _buildHubInvitesTab(),
                _buildSearchTab(currentUserProfile),
              ],
            ),
    );
  }

  Widget _buildSearchTab(UserModel currentUserProfile) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'social_searchLabel'.tr(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'social_searchTooltip'.tr(),
                onPressed: _searchUsers,
              ),
            ),
            onSubmitted: (_) => _searchUsers(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _searchResultsFuture,
            builder: (context, snapshot) {
              if (_searchResultsFuture == null) return Center(child: Text('social_searchPrompt'.tr()));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('social_searchError'.tr(namedArgs: {'error': snapshot.error.toString()})));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('social_noUsersFound'.tr()));
              
              final results = snapshot.data!;
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final user = results[index];
                  return SearchResultTile(
                    user: user,
                    currentUserProfile: currentUserProfile,
                    profileService: _profileService,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHubInvitesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _hubService.getReceivedHubInvitesStream(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return Center(child: Text("social_noHubInvites".tr()));
        
        final invites = snapshot.data!;
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final inviteData = invites[index];
            return ListTile(
              leading: const Icon(Icons.group_add),
              title: Text('social_inviteForHub'.tr(namedArgs: {'hubName': inviteData['hubName'] ?? 'social_nameUnavailable'.tr()})),
              subtitle: Text('social_sentBy'.tr(namedArgs: {'username': inviteData['fromUsername'] ?? 'social_unknownUser'.tr()})),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: Text("social_accept".tr(), style: const TextStyle(color: Colors.green)),
                    onPressed: () => _hubService.acceptHubInvite(inviteData['id']),
                  ),
                  TextButton(
                    child: Text("social_decline".tr(), style: const TextStyle(color: Colors.red)),
                    onPressed: () => _hubService.declineHubInvite(inviteData['id']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
