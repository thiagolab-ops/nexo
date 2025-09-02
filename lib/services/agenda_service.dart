import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class AgendaService {
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<AgendaEvent> get _eventsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('agendaEvents')
          .withConverter<AgendaEvent>(
            fromFirestore: (snapshot, _) => AgendaEvent.fromFirestore(snapshot),
            toFirestore: (event, _) => event.toMap(),
          );

  Stream<List<AgendaEvent>> getAllEventsStream() {
    return _eventsRef.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
  
  Future<void> addEvent(String title, DateTime date) async {
    final newEvent = AgendaEvent(id: '', title: title, date: date);
    await _eventsRef.add(newEvent);
  }
  
  Future<void> toggleEventStatus(AgendaEvent event) async {
    await _eventsRef.doc(event.id).update({'isDone': !event.isDone});
  }
  
  Future<void> deleteEvent(String eventId) async {
    await _eventsRef.doc(eventId).delete();
  }
}
