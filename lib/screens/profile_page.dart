import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;
  bool isSaving = false;
  bool isEditing = false;
  File? _localImageFile;
  String? _networkImageUrl;

  String? selectedBatch;
  String? selectedFaculty;
  String? selectedDegree;

  final TextEditingController initialsController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController nicController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController religionController = TextEditingController();
  final TextEditingController motherNameController = TextEditingController();
  final TextEditingController fatherNameController = TextEditingController();
  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController guardianPhone1Controller = TextEditingController();
  final TextEditingController guardianPhone2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _networkImageUrl = data['profile_pic'];
          initialsController.text = data['initials'] ?? '';
          surnameController.text = data['surname'] ?? '';
          firstNameController.text = data['first_name'] ?? '';
          lastNameController.text = data['last_name'] ?? '';
          studentIdController.text = data['student_id'] ?? '';
          dateController.text = data['birthday'] ?? '';
          selectedBatch = data['batch'];
          selectedFaculty = data['faculty'];
          selectedDegree = data['degree'];
          nicController.text = data['nic'] ?? '';
          phoneController.text = data['phone'] ?? '';
          nationalityController.text = data['nationality'] ?? '';
          religionController.text = data['religion'] ?? '';
          motherNameController.text = data['mother_name'] ?? '';
          fatherNameController.text = data['father_name'] ?? '';
          guardianNameController.text = data['guardian_name'] ?? '';
          addressController.text = data['address'] ?? '';
          guardianPhone1Controller.text = data['guardian_phone1'] ?? '';
          guardianPhone2Controller.text = data['guardian_phone2'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar("Error fetching data", Colors.red);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _localImageFile = File(pickedFile.path));
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      isSaving = true;
      isEditing = false;
    });
    try {
      String? finalImageUrl = _networkImageUrl;

      if (_localImageFile != null) {
        Reference storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user!.uid}.jpg');
        UploadTask uploadTask = storageRef.putFile(_localImageFile!);
        TaskSnapshot snapshot = await uploadTask;
        finalImageUrl = await snapshot.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'profile_pic': finalImageUrl ?? "",
        'initials': initialsController.text,
        'surname': surnameController.text,
        'first_name': firstNameController.text,
        'last_name': lastNameController.text,
        'student_id': studentIdController.text,
        'birthday': dateController.text,
        'batch': selectedBatch,
        'faculty': selectedFaculty,
        'degree': selectedDegree,
        'nic': nicController.text,
        'phone': phoneController.text,
        'nationality': nationalityController.text,
        'religion': religionController.text,
        'mother_name': motherNameController.text,
        'father_name': fatherNameController.text,
        'guardian_name': guardianNameController.text,
        'address': addressController.text,
        'guardian_phone1': guardianPhone1Controller.text,
        'guardian_phone2': guardianPhone2Controller.text,
        'updated_at': Timestamp.now(),
      });

      _showSnackBar("Profile Updated Successfully", Colors.green);
    } catch (e) {
      _showSnackBar("Update Failed", Colors.red);
      setState(() => isEditing = true);
    }
    setState(() => isSaving = false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(10)),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              _showSnackBar("Logged Out", Colors.red);
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => LoginPage()), (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    
    bool hasNetworkImage = _networkImageUrl != null && _networkImageUrl!.isNotEmpty;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_localImageFile != null || hasNetworkImage) {
                        showDialog(context: context, builder: (c) => Dialog(
                          child: _localImageFile != null
                              ? Image.file(_localImageFile!)
                              : Image.network(_networkImageUrl!),
                        ));
                      }
                    },
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _localImageFile != null
                          ? FileImage(_localImageFile!)
                          : (hasNetworkImage ? NetworkImage(_networkImageUrl!) : null) as ImageProvider?,
                      child: (_localImageFile == null && !hasNetworkImage)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showImageMenu(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(user?.email ?? "N/A", style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),

            _sectionHeaderWithAction("Primary Details", Icons.edit, () {
              setState(() => isEditing = !isEditing);
            }),
            const SizedBox(height: 10),
            _buildDoubleField(initialsController, "Initials", surnameController, "Surname"),
            _buildDoubleField(firstNameController, "First Name", lastNameController, "Last Name"),
            _buildSingleField(studentIdController, "Student ID"),

            TextField(
              controller: dateController,
              readOnly: true,
              enabled: isEditing,
              decoration: const InputDecoration(labelText: "Select Your Birthday", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
              onTap: () async {
                DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                if (picked != null) setState(() => dateController.text = "${picked.year}-${picked.month}-${picked.day}");
              },
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                List<String> items = snapshot.hasData ? snapshot.data!.docs.map((d) => d['name'].toString()).toList() : [];
                return _buildDropdown("Select Batch", items, selectedBatch, (val) => setState(() => selectedBatch = val));
              },
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('faculties').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                List<String> items = snapshot.hasData ? snapshot.data!.docs.map((d) => d['name'].toString()).toList() : [];
                return _buildDropdown("Select Faculty", items, selectedFaculty, (val) {
                  setState(() {
                    selectedFaculty = val;
                    selectedDegree = null;
                  });
                });
              },
            ),

            StreamBuilder<QuerySnapshot>(
              stream: selectedFaculty == null
                  ? FirebaseFirestore.instance.collection('degrees').orderBy('name').snapshots()
                  : FirebaseFirestore.instance.collection('degrees').where('faculty', isEqualTo: selectedFaculty).snapshots(),
              builder: (context, snapshot) {
                List<String> items = snapshot.hasData ? snapshot.data!.docs.map((d) => d['name'].toString()).toList() : [];
                return _buildDropdown(
                    selectedFaculty == null ? "Select Faculty First" : "Select Your Degree",
                    items,
                    selectedDegree,
                        (val) => setState(() => selectedDegree = val)
                );
              },
            ),

            const SizedBox(height: 20),
            _sectionHeader("Additional Details"),
            const SizedBox(height: 10),
            _buildSingleField(nicController, "NIC Number"),
            _buildSingleField(phoneController, "Phone Number"),
            _buildSingleField(nationalityController, "Nationality"),
            _buildSingleField(religionController, "Religion"),
            _buildSingleField(addressController, "Home Address"),
            _buildSingleField(motherNameController, "Mother's Name"),
            _buildSingleField(fatherNameController, "Father's Name"),
            _buildSingleField(guardianNameController, "Guardian Name"),
            _buildDoubleField(guardianPhone1Controller, "Guardian Phone 1", guardianPhone2Controller, "Guardian Phone 2"),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: (isSaving || !isEditing) ? null : _updateProfile,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Details", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _confirmLogout,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Logout", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showImageMenu() {
    showModalBottomSheet(
      context: context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.photo_library), title: const Text("Pick New Photo"), onTap: () { Navigator.pop(context); _pickImage(); }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Remove Photo"), onTap: () {
            Navigator.pop(context);
            setState(() { _localImageFile = null; _networkImageUrl = ""; });
          }),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)));

  Widget _sectionHeaderWithAction(String title, IconData icon, VoidCallback onTap) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        IconButton(
          icon: Icon(icon, color: isEditing ? Colors.green : Colors.grey),
          onPressed: onTap,
        ),
      ],
    ),
  );

  Widget _buildSingleField(TextEditingController controller, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
          controller: controller,
          enabled: isEditing,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())
      )
  );

  Widget _buildDoubleField(TextEditingController c1, String l1, TextEditingController c2, String l2) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: TextField(controller: c1, enabled: isEditing, decoration: InputDecoration(labelText: l1, border: const OutlineInputBorder()))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: c2, enabled: isEditing, decoration: InputDecoration(labelText: l2, border: const OutlineInputBorder())))
      ])
  );

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    String? safeValue = items.contains(value) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        style: TextStyle(
          color: isEditing ? Colors.black : Colors.grey[600],
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isEditing ? Colors.black : Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: !isEditing,
          fillColor: Colors.transparent,
        ),
        items: items.map((i) => DropdownMenuItem(
            value: i,
            child: Text(i, style: TextStyle(color: isEditing ? Colors.black : Colors.grey))
        )).toList(),
        onChanged: isEditing ? onChanged : null,
      ),
    );
  }
}
