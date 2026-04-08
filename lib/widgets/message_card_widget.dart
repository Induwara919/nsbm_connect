import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'view_message_widget.dart';

class MessageCard extends StatelessWidget {
  final String announcementId;
  final Map<String, dynamic> data;

  const MessageCard({super.key, required this.announcementId, required this.data});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    final List readBy = data['read_by'] ?? [];
    final bool isUnread = !readBy.contains(uid);

    DateTime date = (data['timestamp'] as Timestamp).toDate();

    return GestureDetector(
      onTap: () {
        if (isUnread) {
          FirebaseFirestore.instance.collection('announcements').doc(announcementId).update({
            'read_by': FieldValue.arrayUnion([uid])
          });
        }
        Navigator.push(context, MaterialPageRoute(builder: (c) => ViewMessageWidget(data: data)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.primary.withOpacity(0.1) : AppColors.secondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isUnread ? AppColors.primary.withOpacity(0.5) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            if (isUnread)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'], style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd MMM yyyy | hh:mm a').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
