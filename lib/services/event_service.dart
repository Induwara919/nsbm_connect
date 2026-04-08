import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<String>> getAllEventDatesStream() {
    return _db.collection('events').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => doc['date'] as String)
          .toSet()
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getEventsByDate(String date) {
    return _db
        .collection('events')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList());
  }

  Stream<List<Map<String, dynamic>>> getUpcomingThreeDaysEvents() {
    DateTime now = DateTime.now();

    List<String> threeDays = [
      DateFormat('d/M/yyyy').format(now),
      DateFormat('d/M/yyyy').format(now.add(const Duration(days: 1))),
      DateFormat('d/M/yyyy').format(now.add(const Duration(days: 2))),
    ];

    return _db
        .collection('events')
        .where('date', whereIn: threeDays)
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> events = snapshot.docs.map((doc) => doc.data()).toList();

      events.sort((a, b) {
        DateTime dateA = DateFormat('d/M/yyyy').parse(a['date']);
        DateTime dateB = DateFormat('d/M/yyyy').parse(b['date']);

        return dateA.compareTo(dateB);
      });

      return events;
    });
  }
}
