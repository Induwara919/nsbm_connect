import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../widgets/post_widget.dart';
import 'add_post_page.dart';
import 'my_posts_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String selectedCategory = "All Posts";
  List<DocumentSnapshot> allPosts = [];
  bool isLoading = false;
  DocumentSnapshot? lastDocument;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadBatch(isInitial: true);
  }

  Future<void> _loadBatch({bool isInitial = false}) async {
    if (isLoading || (!hasMore && !isInitial)) return;

    setState(() => isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(20);

      if (selectedCategory != "All Posts") {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      if (!isInitial && lastDocument != null) {
        query = query.startAfterDocument(lastDocument!);
      }

      QuerySnapshot snap = await query.get();

      if (snap.docs.isEmpty) {
        setState(() {
          if (isInitial) allPosts = [];
          hasMore = false;
          isLoading = false;
        });
        return;
      }

      // --- FIX APPLIED HERE ---
      // PRE-CACHE ALL 20 IMAGES ONLY IF URL IS VALID
      List<Future<void>> cacheFutures = [];
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrl = data['image_url'] as String?;

        // Ensure imageUrl is not null and not an empty string before precaching
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          cacheFutures.add(precacheImage(CachedNetworkImageProvider(imageUrl), context));
        }
      }

      // Wait for images to download (max 10 seconds)
      if (cacheFutures.isNotEmpty) {
        await Future.wait(cacheFutures).timeout(const Duration(seconds: 10), onTimeout: () => []);
      }
      // ------------------------

      setState(() {
        if (isInitial) {
          allPosts = snap.docs;
        } else {
          allPosts.addAll(snap.docs);
          if (allPosts.length > 40) {
            allPosts.removeRange(0, 20);
          }
        }
        lastDocument = snap.docs.last;
        hasMore = snap.docs.length == 20;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _changeCategory(String category) {
    setState(() {
      selectedCategory = category;
      allPosts.clear();
      lastDocument = null;
      hasMore = true;
    });
    _loadBatch(isInitial: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(selectedCategory), centerTitle: true),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          if (allPosts.isEmpty && !isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.post_add, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No posts yet in $selectedCategory.",
                    style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          ListView.builder(
            key: PageStorageKey('community_scroll_$selectedCategory'),
            padding: const EdgeInsets.all(10),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: allPosts.length + (hasMore && !isLoading ? 1 : 0),
            cacheExtent: 5000,
            itemBuilder: (context, index) {
              if (index == allPosts.length) {
                return _buildLoadMoreButton();
              }
              var doc = allPosts[index];
              return PostWidget(
                key: ValueKey(doc.id),
                postId: doc.id,
                postData: doc.data() as Map<String, dynamic>,
              );
            },
          ),

          if (isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 15),
                    Text("Loading...", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: IconButton(
        onPressed: () => _loadBatch(),
        icon: const Icon(Icons.add_circle_outline, size: 50, color: AppColors.primary),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Center(child: Text("Community", style: TextStyle(color: Colors.white, fontSize: 24))),
          ),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text("Add Post"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPostPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("My Posts"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsPage()));
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Categories", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('post_categories').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                var categories = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                categories.insert(0, "All Posts");
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(categories[index]),
                      selected: selectedCategory == categories[index].trim(),
                      onTap: () {
                        _changeCategory(categories[index].trim());
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
