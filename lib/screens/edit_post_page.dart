import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/add_post_service.dart';

class EditPostPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const EditPostPage({super.key, required this.postId, required this.postData});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final AddPostService _postService = AddPostService();

  File? _newImage;
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.postData['title']);
    _descController = TextEditingController(text: widget.postData['description']);
    _selectedCategory = widget.postData['category'];
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _newImage = File(pickedFile.path));
  }

  void _update() async {
    setState(() => _isLoading = true);
    bool success = await _postService.updatePost(
      postId: widget.postId,
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory!,
      newImageFile: _newImage,
      existingImageUrl: widget.postData['image_url'],
    );
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post Updated!"), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Post"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _newImage != null
                      ? Image.file(_newImage!, fit: BoxFit.contain)
                      : Image.network(widget.postData['image_url'], fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _titleController, maxLength: 50, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _descController, maxLength: 300, maxLines: 4, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('post_categories').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                var cats = snapshot.data!.docs.map((d) => d['name'] as String).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                );
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _update,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Update Post", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
