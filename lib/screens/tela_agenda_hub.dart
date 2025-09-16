import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class TelaAgendaHub extends StatefulWidget {
  final String hubId;
  final String hubName;
  // ACEITA OS PARÂMETROS DO PAI (tela_hub_detalhe)
  final Function({HubEvent? eventToEdit}) showEventDialog;
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
  late final NexoHubService _hubService;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mapa para armazenar os eventos agrupados por data
  Map<DateTime, List<HubEvent>> _eventsMap = {};

  @override
  void initState() {
    super.initState();
    _hubService = context.read<NexoHubService>();
    _selectedDay = _focusedDay;
  }

  List<HubEvent> _getEventsForDay(DateTime day) {
    // Retorna a lista de eventos para o dia selecionado (ignorando a hora)
    return _eventsMap[DateTime(day.year, day.month, day.day)] ?? [];
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
      stream: _hubService.getEventsStream(widget.hubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar eventos: ${snapshot.error}'));
        }

        final allEvents = snapshot.data ?? [];
        // Processa os eventos para o mapa
        _eventsMap = {};
        for (final event in allEvents) {
          final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
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
              eventLoader: _getEventsForDay, // Mostra o marcador no calendário
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
                  bool isOwner = event.creatorId == widget.currentUserProfile.id;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text(event.title),
                      subtitle: Text('Criado por ${event.creatorUsername}'),
                      trailing: (isOwner || widget.currentUserProfile.role == 'professor')
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Editar Título',
                                onPressed: () {
                                  // CHAMA A FUNÇÃO DO PAI
                                  widget.showEventDialog(eventToEdit: event);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                tooltip: 'Excluir Evento',
                                onPressed: () {
                                  // Deleta diretamente
                                  _hubService.deleteEventFromHub(widget.hubId, event.id);
                                },
                              ),
                            ],
                          )
                        : null,
                      // AQUI VAI ENTRAR NOSSA LÓGICA DE RSVP
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
