import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'view_post_page.dart';
import 'edit_post_page.dart';
import 'login_page.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  int _myPostsLimit = 20;
  int _savedPostsLimit = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          var userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          List savedIds = userData['saved_posts'] ?? [];

          return Column(
            children: [
              _buildProfileHeader(userData),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: "My Posts"),
                  Tab(icon: Icon(Icons.bookmark_outline), text: "Saved"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGridSection(isSaved: false, ids: []),
                    _buildGridSection(isSaved: true, ids: savedIds),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    List savedIds = user['saved_posts'] ?? [];

    // --- FIX APPLIED HERE ---
    String profilePicUrl = user['profile_pic'] ?? '';
    bool hasImage = profilePicUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: hasImage ? NetworkImage(profilePicUrl) : null,
            child: !hasImage ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
          ),
          const SizedBox(height: 10),
          Text(
              "${user['initials'] ?? ''} ${user['first_name'] ?? ''} ${user['last_name'] ?? ''} ${user['surname'] ?? ''}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('author_id', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _countColumn(count, "Posts");
                },
              ),
              savedIds.isEmpty
                  ? _countColumn(0, "Saved")
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where(FieldPath.documentId, whereIn: savedIds.take(30).toList())
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _countColumn(count, "Saved");
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countColumn(int count, String label) {
    return Column(
      children: [
        Text("$count", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildGridSection({required bool isSaved, required List ids}) {
    Query query = FirebaseFirestore.instance.collection('posts');

    if (isSaved) {
      if (ids.isEmpty) return const Center(child: Text("No saved posts yet."));
      query = query.where(FieldPath.documentId, whereIn: ids.take(30).toList());
    } else {
      query = query.where('author_id', isEqualTo: uid).orderBy('timestamp', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(isSaved ? _savedPostsLimit : _myPostsLimit).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Query failed. Ensure indexes are created."),
            ),
          );
        }

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("Nothing to show here."));

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                return _gridTile(docs[index].id, data, !isSaved);
              },
            ),
            if (docs.length >= (isSaved ? _savedPostsLimit : _myPostsLimit))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: IconButton(
                    onPressed: () => setState(() {
                      if (isSaved) _savedPostsLimit += 20; else _myPostsLimit += 20;
                    }),
                    icon: const Icon(Icons.add_circle_outline, size: 40, color: AppColors.primary),
                  ),
                ),
              )
          ],
        );
      },
    );
  }

  Widget _gridTile(String id, Map<String, dynamic> data, bool showOptions) {
    // --- FIX APPLIED HERE ---
    String postImageUrl = data['image_url'] ?? '';
    bool hasPostImage = postImageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewPostPage(postId: id, postData: data),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
              child: hasPostImage
                  ? Image.network(postImageUrl, fit: BoxFit.cover)
                  : Container(color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.white70))
          ),
          if (showOptions)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 18,
                  ),
                  offset: const Offset(0, 30),
                  onSelected: (val) {
                    if (val == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditPostPage(postId: id, postData: data),
                        ),
                      );
                    }
                    if (val == 'delete') _confirmDelete(id);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Text("Edit")
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text("Delete", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('posts').doc(id).delete();
                if (mounted) Navigator.pop(c);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
