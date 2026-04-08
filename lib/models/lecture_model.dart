class Lecture {
  final String startTime;
  final String endTime;
  final String subject;
  final String lecturer;
  final String location;
  final String? note;

  Lecture({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.lecturer,
    required this.location,
    this.note,
  });

  
  factory Lecture.fromFirestore(Map<String, dynamic> json) {
    return Lecture(
      startTime: (json['start_time'] ?? "00:00 AM") as String,
      endTime: (json['end_time'] ?? "00:00 PM") as String,
      subject: (json['subject'] ?? "No Title") as String,
      lecturer: (json['lecturer'] ?? 'Staff').toString(),
      location: (json['lecture_hall'] ?? 'TBD').toString(),
      note: json['notes']?.toString() ?? '',
    );
  }
}
