import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentSection extends StatelessWidget {
  final String postId;
  final TextEditingController _commentController = TextEditingController();

  CommentSection({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('comments')
                  .where('post_id', isEqualTo: postId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No comments yet.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return CommentItem(
                      commentId: doc.id,
                      data: doc.data() as Map<String, dynamic>,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildCommentInput(context),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
      builder: (context, snapshot) {
        String? profilePicUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          profilePicUrl = userData?['profile_pic'];
        }

        
        bool hasImage = profilePicUrl != null && profilePicUrl.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(
              left: 15,
              right: 15,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 15
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: hasImage ? NetworkImage(profilePicUrl!) : null,
                child: !hasImage ? const Icon(Icons.person, size: 18, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
                  child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(hintText: "Add a comment...", border: InputBorder.none)
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.blue),
                onPressed: () async {
                  if (_commentController.text.trim().isNotEmpty) {
                    final txt = _commentController.text.trim();
                    _commentController.clear();
                    await FirebaseFirestore.instance.collection('comments').add({
                      'post_id': postId,
                      'user_id': currentUserId,
                      'text': txt,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) FocusScope.of(context).unfocus();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class CommentItem extends StatefulWidget {
  final String commentId;
  final Map<String, dynamic> data;

  const CommentItem({super.key, required this.commentId, required this.data});

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool isExpanded = false;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _showEditDialog(String currentText) {
    TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Comment"),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('comments')
                    .doc(widget.commentId)
                    .update({'text': editController.text.trim()});
              }
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _deleteComment() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment"),
        content: const Text("Are you sure you want to delete this comment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('comments').doc(widget.commentId).delete();
    }
  }

  Widget _buildDeletedUserComment() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, child: Icon(Icons.person_off, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Deleted User", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(widget.data['text'] ?? '', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.data['user_id']).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 10);
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDeletedUserComment();
        }

        var user = snapshot.data!.data() as Map<String, dynamic>?;
        if (user == null) return const SizedBox();

        bool isMyComment = widget.data['user_id'] == currentUserId;
        String? profilePic = user['profile_pic'];

        // --- FIX APPLIED HERE ---
        bool hasImage = profilePic != null && profilePic.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.vertical(top: Radius.circular(15), bottom: Radius.circular(15)),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: hasImage ? NetworkImage(profilePic!) : null,
                    child: !hasImage ? const Icon(Icons.person, size: 18, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "${user['initials'] ?? ''} ${user['first_name'] ?? ''} ${user['last_name'] ?? ''} ${user['surname'] ?? ''}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                        Text(
                            "${user['batch'] ?? ''} | ${user['faculty'] ?? ''} | ${user['degree'] ?? ''}",
                            style: const TextStyle(fontSize: 10, color: Colors.grey)
                        ),
                      ],
                    ),
                  ),
                  if (isMyComment)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(widget.data['text']);
                        } else if (value == 'delete') {
                          _deleteComment();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text("Edit")),
                        const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data['text'] ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      maxLines: isExpanded ? 100 : 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((widget.data['text'] ?? '').length > 100)
                      GestureDetector(
                        onTap: () => setState(() => isExpanded = !isExpanded),
                        child: Text(
                            isExpanded ? "Read Less" : "Read More",
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                        timeago.format(widget.data['timestamp']?.toDate() ?? DateTime.now()),
                        style: const TextStyle(fontSize: 10, color: Colors.grey)
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
