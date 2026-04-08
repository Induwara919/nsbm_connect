import 'package:cloud_firestore/cloud_firestore.dart';

class NewsArticleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getNewsStream() {
    return _firestore
        .collection('news_updates')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
