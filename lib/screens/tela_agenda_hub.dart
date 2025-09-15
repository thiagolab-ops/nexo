import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

enum Audience { hub, followers }

class TelaAgendaHub extends StatefulWidget {
  final String hubId;
  final String hubName;
  final Function({HubEvent? eventToEdit}) showEventDialog; // Para chamar o dialog do pai
  final UserModel currentUserProfile;

  const TelaAgendaHub({
    super.key, 
    required this.hubId, 
    required this.hubName,
    required this.showEventDialog,
    required this.currentUserProfile,
  });

  @override
  State<TelaAgendaHub> createState() => _TelaAgendaHubState();
}

class _TelaAgendaHubState extends State<TelaAgendaHub> {
  final NexoHubService _hubService = NexoHubService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late Stream<List<HubEvent>> _eventsStream;
  
  LinkedHashMap<DateTime, List<HubEvent>> _eventsByDay = LinkedHashMap(
    equals: isSameDay, 
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year
  );
  
  List<HubEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _eventsStream = _hubService.getEventsStream(widget.hubId);
  }

  List<HubEvent> _getEventsForDay(DateTime day) {
    final dayUtc = DateTime.utc(day.year, day.month, day.day);
    return _eventsByDay[dayUtc] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HubEvent>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _allEvents = snapshot.data!;
          final newEventsByDay = LinkedHashMap<DateTime, List<HubEvent>>(
            equals: isSameDay,
            hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
          );
          for (var event in _allEvents) {
            final day = DateTime.utc(event.date.year, event.date.month, event.date.day);
            if (newEventsByDay[day] == null) {
              newEventsByDay[day] = [];
            }
            newEventsByDay[day]!.add(event);
          }
          _eventsByDay = newEventsByDay;
        }
        
        final selectedDayEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

        return Column(
          children: [
            TableCalendar<HubEvent>(
              key: ValueKey(_allEvents.length),
              locale: 'pt_BR',
              firstDay: DateTime.utc(2022, 1, 1),
              lastDay: DateTime.utc(2032, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              eventLoader: _getEventsForDay,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false),
              onPageChanged: (focusedDay) {
                setState(() {
                    _focusedDay = focusedDay;
                });
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80.0), 
                itemCount: selectedDayEvents.length,
                itemBuilder: (context, index) {
                  final event = selectedDayEvents[index];
                  return _buildEventCard(event);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(HubEvent event) {
    final bool isCreator = event.creatorId == _currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(event.meetLink != null && event.meetLink!.isNotEmpty ? Icons.videocam : Icons.event_note),
              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Criado por: ${event.creatorUsername}'),
              trailing: isCreator ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    widget.showEventDialog(eventToEdit: event);
                  } else if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Excluir Evento'),
                        content: Text('Tem certeza que deseja excluir "${event.title}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _hubService.deleteEventFromHub(widget.hubId, event.id);
                            },
                            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>( value: 'edit', child: Text('Editar')),
                  const PopupMenuItem<String>( value: 'delete', child: Text('Excluir')),
                ],
              ) : null,
            ),
            const Divider(),
            _buildRsvpSection(event),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRsvpSection(HubEvent event) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _hubService.getUserRsvpStatusStream(widget.hubId, event.id, _currentUserId),
      builder: (context, snapshot) {
        String? myStatus;
        if (snapshot.hasData && snapshot.data!.exists) {
          myStatus = (snapshot.data!.data() as Map<String, dynamic>)['status'];
        }

        final bool isAttending = myStatus == 'attending';
        final bool isDeclined = myStatus == 'declined';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Vou!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAttending ? Colors.green : Colors.grey[800],
                  ),
                  onPressed: () {
                    _hubService.setRsvpForEvent(
                      hubId: widget.hubId,
                      eventId: event.id,
                      userId: _currentUserId,
                      username: widget.currentUserProfile.username,
                      status: 'attending',
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Não vou'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeclined ? Colors.redAccent : Colors.grey[800],
                  ),
                  onPressed: () {
                     _hubService.setRsvpForEvent(
                      hubId: widget.hubId,
                      eventId: event.id,
                      userId: _currentUserId,
                      username: widget.currentUserProfile.username,
                      status: 'declined',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Confirmados:', style: TextStyle(fontWeight: FontWeight.bold)),
            StreamBuilder<List<String>>(
              stream: _hubService.getAttendingUsernamesStream(widget.hubId, event.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Carregando...');
                if (snapshot.data!.isEmpty) return const Text('Ninguém confirmou presença ainda.');
                return Text(snapshot.data!.join(', '));
              }
            )
          ],
        );
      },
    );
  }
}
