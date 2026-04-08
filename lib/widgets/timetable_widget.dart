import 'package:flutter/material.dart';
import '../models/lecture_model.dart';
import '../services/timetable_service.dart';
import '../theme.dart';
import '../screens/map_page.dart';

class TimetableWidget extends StatelessWidget {
  final String userBatch;
  final String userDegree;
  final String dateToFind;
  final TimetableService _service = TimetableService();

  TimetableWidget({
    super.key,
    required this.userBatch,
    required this.userDegree,
    required this.dateToFind,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lecture>>(
      stream: _service.getTimetableStream(
        batch: userBatch,
        degree: userDegree,
        date: dateToFind,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final lectures = snapshot.data ?? [];

        if (lectures.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: lectures.map((lec) => _buildCard(context, lec)).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15)
      ),
      child: const Text(
        "No Lectures today. Enjoy your free time!",
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Lecture lec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "${lec.startTime} To ${lec.endTime}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                    ),
                    const SizedBox(height: 6),
                    Text(
                        lec.subject,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)
                    ),
                    const SizedBox(height: 6),
                    Text(
                        lec.lecturer,
                        style: const TextStyle(fontSize: 14, color: Colors.black87)
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                        "Location",
                        style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)
                    ),
                    Text(
                        lec.location,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondary)
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapPage(destinationLabel: lec.location),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Navigate", style: TextStyle(fontSize: 11)),
                    )
                  ],
                ),
              )
            ],
          ),
          if (lec.note != null && lec.note!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1),
            ),
            Text(
              "Note: ${lec.note}",
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ]
        ],
      ),
    );
  }
}
