import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AddPostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // COMPRESS IMAGE
  Future<File?> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final String targetPath = p.join(path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, 
    );

    return result != null ? File(result.path) : null;
  }

  // UPLOAD POST LOGIC
  Future<bool> uploadPost({
    required String title,
    required String description,
    required String category,
    required File imageFile,
  }) async {
    try {
      String uid = _auth.currentUser!.uid;

      // 1. Compress
      File? compressedFile = await compressImage(imageFile);
      if (compressedFile == null) return false;

      // 2. Upload to Storage
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = _storage.ref().child('post_images').child(fileName);
      UploadTask uploadTask = ref.putFile(compressedFile);
      TaskSnapshot snapshot = await uploadTask;
      String imageUrl = await snapshot.ref.getDownloadURL();

      // 3. Save to Firestore
      await _db.collection('posts').add({
        'title': title,
        'description': description,
        'category': category,
        'image_url': imageUrl,
        'author_id': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'dislikes': [],
      });

      return true;
    } catch (e) {
      print("Upload Error: $e");
      return false;
    }
  }
  Future<bool> updatePost({
    required String postId,
    required String title,
    required String description,
    required String category,
    File? newImageFile,
    required String existingImageUrl,
  }) async {
    try {
      String finalImageUrl = existingImageUrl;

      
      if (newImageFile != null) {
        File? compressed = await compressImage(newImageFile);
        if (compressed != null) {
          String fileName = "updated_${DateTime.now().millisecondsSinceEpoch}.jpg";
          Reference ref = _storage.ref().child('post_images').child(fileName);
          await ref.putFile(compressed);
          finalImageUrl = await ref.getDownloadURL();
        }
      }

      await _db.collection('posts').doc(postId).update({
        'title': title,
        'description': description,
        'category': category,
        'image_url': finalImageUrl,
      });
      return true;
    } catch (e) {
      print("Update Error: ${e.toString()}");
      return false;
    }
  }
}
