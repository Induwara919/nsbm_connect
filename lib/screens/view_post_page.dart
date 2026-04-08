import 'package:flutter/material.dart';
import '../widgets/post_widget.dart';

class ViewPostPage extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const ViewPostPage({super.key, required this.postId, required this.postData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post"), centerTitle: true),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          // We reuse your existing PostWidget here!
          child: PostWidget(postId: postId, postData: postData),
        ),
      ),
    );
  }
}
