import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/lecture_model.dart';
import '../widgets/timetable_widget.dart';

class TimetableService {
  
  Stream<List<Lecture>> getTimetableStream({
    required String batch,
    required String degree,
    required String date,
  }) {
    return FirebaseFirestore.instance
        .collection('timetable')
        .where('batch', isEqualTo: batch)
        .where('degree', isEqualTo: degree)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Lecture.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  
  Widget displayTodayTimetable(String todayDateISO, String currentUserId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        String batch = userData['batch'] ?? "";
        String degree = userData['degree'] ?? "";

        if (batch.isEmpty || degree.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                  "Please update your profile batch/degree to see your timetable."),
            ),
          );
        }

  
        return TimetableWidget(
          userBatch: batch,
          userDegree: degree,
          dateToFind: todayDateISO,
        );
      },
    );
  }
}
