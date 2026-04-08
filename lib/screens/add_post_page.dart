import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/add_post_service.dart';
import 'login_page.dart';

class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final AddPostService _postService = AddPostService();

  File? _selectedImage;
  String? _selectedCategory;
  bool _isLoading = false;

  // Pick Image Function
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  // Show Custom SnackBar
  void _showStatusSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _submitPost() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty ||
        _selectedImage == null || _selectedCategory == null) {
      _showStatusSnackBar("Please fill all fields and pick an image", false);
      return;
    }

    setState(() => _isLoading = true);

    bool success = await _postService.uploadPost(
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory!,
      imageFile: _selectedImage!,
    );

    setState(() => _isLoading = false);

    if (success) {
      _showStatusSnackBar("Post uploaded successfully!", true);
      Navigator.pop(context);
    } else {
      _showStatusSnackBar("Upload failed. Try again.", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        // 1. Updated leading to use a back arrow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Changed from message_rounded
          onPressed: () {
            // 2. This function removes the current screen and goes back
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // IMAGE PREVIEW / PICKER
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.contain,
                    ),
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text("Tap to select image", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // TITLE INPUT
              TextField(
                controller: _titleController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "Enter post title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // DESCRIPTION INPUT
              TextField(
                controller: _descController,
                maxLength: 300,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Enter post description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // CATEGORY DROPDOWN
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('post_categories').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  var categories = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Category"),
                    value: _selectedCategory,
                    hint: const Text("Select Category"),
                    items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  );
                },
              ),
              const SizedBox(height: 30),

              // UPLOAD BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Upload Post", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
