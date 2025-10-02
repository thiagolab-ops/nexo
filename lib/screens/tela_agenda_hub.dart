import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaAgendaHub extends StatefulWidget {
  final String hubId;
  final String hubName;
  final Function({HubEvent? eventToEdit}) showEventDialog;
  final UserModel currentUserProfile;
  final void Function(DateTime) onDaySelectedCallback;

  const TelaAgendaHub({
    super.key,
    required this.hubId,
    required this.hubName,
    required this.showEventDialog,
    required this.currentUserProfile,
    required this.onDaySelectedCallback,
  });

  @override
  State<TelaAgendaHub> createState() => _TelaAgendaHubState();
}

class _TelaAgendaHubState extends State<TelaAgendaHub> {
  late final NexoHubService _hubService;
  late final ProfileService _profileService;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<HubEvent>> _eventsMap = {};

  @override
  void initState() {
    super.initState();
    _hubService = context.read<NexoHubService>();
    _profileService = context.read<ProfileService>();
    _selectedDay = _focusedDay;
  }
  
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  List<HubEvent> _getEventsForDay(DateTime day) {
    // CORREÇÃO: Usa DateTime.utc ao MEIO-DIA para a chave de busca
    final dayUtc = DateTime.utc(day.year, day.month, day.day, 12);
    return _eventsMap[dayUtc] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        // CORREÇÃO: Garante que a data selecionada seja sempre ao MEIO-DIA UTC
        _selectedDay = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day, 12);
        _focusedDay = DateTime.utc(focusedDay.year, focusedDay.month, focusedDay.day, 12);
        widget.onDaySelectedCallback(_selectedDay!);
      });
    }
  }

  void _handleRsvp(HubEvent event, bool isAttending) {
    _hubService.rsvpToEvent(
      hubId: widget.hubId,
      eventId: event.id,
      userId: widget.currentUserProfile.id,
      isAttending: isAttending,
    );
  }

  void _showAttendeesDialog(HubEvent event) {
    if (event.attendees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ninguém confirmou presença ainda.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lista de Confirmados (${event.attendees.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<UserModel>>(
            future: _profileService.getUsersFromIdList(event.attendees),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: UserAvatar(username: user.username, photoUrl: user.photoUrl),
                    title: Text(user.username),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HubEvent>>(
      stream: _hubService.getEventsStream(widget.hubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar eventos: ${snapshot.error}'));
        }

        final allEvents = snapshot.data ?? [];
        _eventsMap = {};
        for (final event in allEvents) {
          final localDate = event.date;
          // CORREÇÃO: Cria a chave do mapa usando MEIO-DIA UTC
          final eventDay = DateTime.utc(localDate.year, localDate.month, localDate.day, 12);
          if (_eventsMap[eventDay] == null) {
            _eventsMap[eventDay] = [];
          }
          _eventsMap[eventDay]!.add(event);
        }

        final selectedDayEvents = _getEventsForDay(_selectedDay ?? DateTime.now());

        return Column(
          children: [
            TableCalendar<HubEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              eventLoader: _getEventsForDay,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: selectedDayEvents.length,
                itemBuilder: (context, index) {
                  final event = selectedDayEvents[index];
                  final bool isOwner = event.creatorId == widget.currentUserProfile.id;
                  final bool isProfessor = widget.currentUserProfile.isPrivileged;
                  final bool isAttending = event.attendees.contains(widget.currentUserProfile.id);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(event.title, style: Theme.of(context).textTheme.titleLarge),
                              ),
                              if (isOwner || isProfessor)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      tooltip: 'Editar Título',
                                      onPressed: () => widget.showEventDialog(eventToEdit: event),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                      tooltip: 'Excluir Evento',
                                      onPressed: () => _hubService.deleteEventFromHub(widget.hubId, event.id),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          Text('Criado por ${event.creatorUsername}', style: Theme.of(context).textTheme.bodySmall),
                          if(event.meetLink != null) ...[
                            const SizedBox(height: 8),
                             InkWell(
                              child: const Text('Entrar na aula', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                              onTap: () => _launchURL(event.meetLink!),
                            ),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _showAttendeesDialog(event),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                    const SizedBox(width: 8),
                                    Text('${event.attendees.length} Confirmados', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: const Text('Vou'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAttending ? Colors.green : Colors.grey[700],
                                  ),
                                  onPressed: isAttending ? null : () => _handleRsvp(event, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.close),
                                  label: const Text('Não Vou'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAttending ? Colors.grey[700] : null,
                                  ),
                                  onPressed: !isAttending ? null : () => _handleRsvp(event, false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
