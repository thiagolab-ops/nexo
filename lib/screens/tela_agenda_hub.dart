import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';

class TelaAgendaHub extends StatefulWidget {
  final String hubId;
  final String hubName;
  
  const TelaAgendaHub({super.key, required this.hubId, required this.hubName});

  @override
  _TelaAgendaHubState createState() => _TelaAgendaHubState();
}

class _TelaAgendaHubState extends State<TelaAgendaHub> {
  final NexoHubService _hubService = NexoHubService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  HubEvent? _eventToEdit;
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hubName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<HubEvent>>(
              stream: _hubService.getEventsStream(widget.hubId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum evento encontrado'));
                }
                
                final events = snapshot.data!;
                
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return ListTile(
                      title: Text(event.title),
                      subtitle: Text('${event.date.day}/${event.date.month}/${event.date.year}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEventDialog(eventToEdit: event);
                          } else if (value == 'delete') {
                            _hubService.deleteEventFromHub(widget.hubId, event.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Excluir'),
                          ),
                        ],
                      ),
                      onTap: () => _showEventDialog(eventToEdit: event),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _showEventDialog(),
              child: const Text('Adicionar Evento'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDialog({HubEvent? eventToEdit}) {
    _isEditing = eventToEdit != null;
    
    if (_isEditing) {
      _eventToEdit = eventToEdit;
      _titleController.text = eventToEdit!.title;
      _descriptionController.text = eventToEdit.description ?? '';
      _locationController.text = eventToEdit.location ?? '';
      _selectedDate = eventToEdit.date;
      _selectedStartTime = TimeOfDay.fromDateTime(eventToEdit.date);
      _selectedEndTime = TimeOfDay.fromDateTime(eventToEdit.endTime);
    } else {
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _selectedDate = null;
      _selectedStartTime = null;
      _selectedEndTime = null;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditing ? 'Editar Evento' : 'Adicionar Evento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Localização'),
              ),
              ListTile(
                title: const Text('Data'),
                trailing: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  child: Text(_selectedDate != null 
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Selecionar data'),
                ),
              ),
              ListTile(
                title: const Text('Horário de início'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedStartTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => _selectedStartTime = time);
                    }
                  },
                  child: Text(_selectedStartTime?.format(context) ?? 'Selecionar horário'),
                ),
              ),
              ListTile(
                title: const Text('Horário de término'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedEndTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => _selectedEndTime = time);
                    }
                  },
                  child: Text(_selectedEndTime?.format(context) ?? 'Selecionar horário'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty && 
                  _selectedDate != null && 
                  _selectedStartTime != null && 
                  _selectedEndTime != null) {
                
                final startTime = DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                  _selectedStartTime!.hour,
                  _selectedStartTime!.minute,
                );
                
                final endTime = DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                  _selectedEndTime!.hour,
                  _selectedEndTime!.minute,
                );
                
                if (_isEditing) {
                  _hubService.updateEventInHub(
                    hubId: widget.hubId,
                    eventId: eventToEdit!.id,
                    title: _titleController.text,
                    description: _descriptionController.text,
                    date: startTime,
                    endTime: endTime,
                    location: _locationController.text,
                  );
                } else {
                  _hubService.addEventToHub(
                    hubId: widget.hubId,
                    title: _titleController.text,
                    description: _descriptionController.text,
                    date: startTime,
                    endTime: endTime,
                    location: _locationController.text,
                  );
                }
                
                Navigator.of(context).pop();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
