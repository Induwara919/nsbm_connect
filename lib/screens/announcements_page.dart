import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/message_card_widget.dart';
import '../theme.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), 
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
            "NSBM Connect",
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 23,
                fontWeight: FontWeight.bold
            )
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Image.asset(
              'assets/images/nsbm_logo.png',
              width: 80,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          var userData = userSnap.data!.data() as Map<String, dynamic>;
          String userBatch = userData['batch'] ?? "";
          String userFaculty = userData['faculty'] ?? "";
          String userDegree = userData['degree'] ?? "";

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(child: Text("No announcements found"));
              }

              final filtered = snap.data!.docs.where((doc) {
                var d = doc.data() as Map<String, dynamic>;
                String mode = d['mode'] ?? "";
                List recipients = d['recipients'] ?? [];

                if (mode == 'all') return true;

                if (mode == 'specific') {
                  return recipients.any((r) => r['uid'] == uid);
                }

                if (mode == 'group') {
                  return recipients.any((r) {
                    bool batchMatch = r['batch'] == "All Batches" || r['batch'] == userBatch;

                    bool facultyMatch = r['faculty'] == "All Faculties" || r['faculty'] == userFaculty;

                    bool degreeMatch = r['degree'] == "All Degrees" || r['degree'] == userDegree || r['degree'] == null;

                    return batchMatch && facultyMatch && degreeMatch;
                  });
                }

                return false;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text("No announcements for your group"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: filtered.length,
                itemBuilder: (c, i) => MessageCard(
                    announcementId: filtered[i].id,
                    data: filtered[i].data() as Map<String, dynamic>
                ),
              );
            },
          );
        },
      ),
    );
  }
}
