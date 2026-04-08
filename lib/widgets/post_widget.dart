import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comment_widget.dart';
import '../theme.dart';

class PostWidget extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostWidget({super.key, required this.postId, required this.postData});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}


class _PostWidgetState extends State<PostWidget> with AutomaticKeepAliveClientMixin {
  bool isExpanded = false;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  bool get wantKeepAlive => true; 

  void handleLikeDislike(bool isLike) async {
    DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;
      List likes = List.from(snapshot.get('likes') ?? []);
      List dislikes = List.from(snapshot.get('dislikes') ?? []);
      if (isLike) {
        if (likes.contains(currentUserId)) {
          likes.remove(currentUserId);
        } else {
          likes.add(currentUserId);
          dislikes.remove(currentUserId);
        }
      } else {
        if (dislikes.contains(currentUserId)) {
          dislikes.remove(currentUserId);
        } else {
          dislikes.add(currentUserId);
          likes.remove(currentUserId);
        }
      }
      transaction.update(postRef, {'likes': likes, 'dislikes': dislikes});
    });
  }

  void handleSavePost(bool isSaved) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    if (isSaved) {
      await userRef.update({'saved_posts': FieldValue.arrayRemove([widget.postId])});
    } else {
      await userRef.update({'saved_posts': FieldValue.arrayUnion([widget.postId])});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    var liveData = widget.postData;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorHeader(liveData['author_id']),

          if (liveData['image_url'] != null && liveData['image_url'].isNotEmpty)
            CachedNetworkImage(
              imageUrl: liveData['image_url'],
              width: double.infinity,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 250, color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
            ),

          _buildActionRow(),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(liveData['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(
                  liveData['description'] ?? '',
                  maxLines: isExpanded ? 100 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
                if ((liveData['description'] ?? '').length > 100)
                  GestureDetector(
                    onTap: () => setState(() => isExpanded = !isExpanded),
                    child: Text(isExpanded ? "Read Less" : "Read More", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 10),
                Text(
                    liveData['timestamp'] != null
                        ? DateFormat('dd,MM,yyyy HH:mm').format(liveData['timestamp'].toDate())
                        : "Now",
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader(String authorId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(authorId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const ListTile(title: Text("..."));
        var author = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        // Safety check for profile picture URL
        String profilePicUrl = author['profile_pic'] ?? '';
        bool hasImage = profilePicUrl.isNotEmpty;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            backgroundImage: hasImage ? NetworkImage(profilePicUrl) : null,
            child: !hasImage ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          title: Text("${author['initials'] ?? ''} ${author['first_name'] ?? ''} ${author['last_name'] ?? ''} ${author['surname'] ?? ''}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text("${author['batch'] ?? ''} | ${author['faculty'] ?? ''} | ${author['degree'] ?? ''}", style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  Widget _buildActionRow() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
        builder: (context, snapshot) {
          var snapData = snapshot.data?.data() as Map<String, dynamic>? ?? widget.postData;
          List likes = snapData['likes'] ?? [];
          List dislikes = snapData['dislikes'] ?? [];
          bool isLiked = likes.contains(currentUserId);
          bool isDisliked = dislikes.contains(currentUserId);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                _iconButton(isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                    likes.length, isLiked ? Colors.blue : Colors.black87, () => handleLikeDislike(true)),
                _iconButton(isDisliked ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
                    dislikes.length, isDisliked ? Colors.red : Colors.black87, () => handleLikeDislike(false)),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('comments')
                      .where('post_id', isEqualTo: widget.postId)
                      .snapshots(),
                  builder: (context, commentSnap) {
                    int commentCount = commentSnap.data?.docs.length ?? 0;
                    return _iconButton(Icons.comment_outlined, commentCount, Colors.black87, () => _showComments(context));
                  },
                ),

                const Spacer(),
                _buildSaveButton(),
              ],
            ),
          );
        }
    );
  }

  Widget _buildSaveButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
      builder: (context, snapshot) {
        List saved = (snapshot.data?.data() as Map<String, dynamic>?)?['saved_posts'] ?? [];
        bool isSaved = saved.contains(widget.postId);
        return IconButton(
          icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? AppColors.primary : Colors.black87),
          onPressed: () => handleSavePost(isSaved),
        );
      },
    );
  }

  Widget _iconButton(IconData icon, int count, Color color, VoidCallback onTap) {
    return Row(children: [
      IconButton(icon: Icon(icon, size: 22, color: color), onPressed: onTap),
      Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      const SizedBox(width: 10)
    ]);
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSection(postId: widget.postId),
    );
  }
}
