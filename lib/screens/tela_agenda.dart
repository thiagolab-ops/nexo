import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/models.dart';
import '../services/agenda_service.dart';

class TelaAgenda extends StatefulWidget {
  const TelaAgenda({super.key});

  @override
  State<TelaAgenda> createState() => _TelaAgendaState();
}

class _TelaAgendaState extends State<TelaAgenda> {
  final AgendaService _agendaService = AgendaService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }
  
  void _showAddEventDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Novo Evento'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Título do Evento'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                final dayToAdd = _selectedDay ?? _focusedDay;
                _agendaService.addEvent(titleController.text, dayToAdd);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        heroTag: 'fab_agenda',
        tooltip: 'Adicionar Evento',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<AgendaEvent>>(
        stream: _agendaService.getAllEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final allEvents = snapshot.data ?? [];
          
          final eventsByDay = LinkedHashMap<DateTime, List<AgendaEvent>>(
            equals: isSameDay,
            hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
          )..addAll({
              for (var event in allEvents)
                DateTime.utc(event.date.year, event.date.month, event.date.day):
                  allEvents.where((e) => isSameDay(e.date, event.date)).toList()
            });

          final selectedDayEvents = eventsByDay[DateTime.utc(
            _selectedDay?.year ?? _focusedDay.year,
            _selectedDay?.month ?? _focusedDay.month,
            _selectedDay?.day ?? _focusedDay.day,
          )] ?? [];

          return Column(
            children: [
              TableCalendar<AgendaEvent>(
                locale: 'pt_BR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _onDaySelected,
                eventLoader: (day) => eventsByDay[DateTime.utc(day.year, day.month, day.day)] ?? [],
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedDayEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedDayEvents[index];
                    return ListTile(
                      leading: Checkbox(
                        value: event.isDone,
                        onChanged: (_) => _agendaService.toggleEventStatus(event),
                      ),
                      title: Text(
                        event.title,
                        style: TextStyle(
                          decoration: event.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _agendaService.deleteEvent(event.id),
                        ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
