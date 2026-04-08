import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_page.dart';
import '../services/send_otp.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String? dropdown1Value; 
  String? dropdown2Value; 
  String? dropdown3Value; 

  TextEditingController dateController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController otpController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController initialsController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController surnameController = TextEditingController();
  TextEditingController studentIdController = TextEditingController();

  bool isCountingDown = false;
  int secondsRemaining = 30;
  Timer? timer;
  bool isLoading = false;
  bool isSendingOtp = false;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void startCountdown() {
    setState(() {
      isCountingDown = true;
      secondsRemaining = 30;
    });

    timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
        setState(() {
          isCountingDown = false;
        });
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> registerUser() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();
    String otp = otpController.text.trim();

    if (!email.endsWith("@students.nsbm.ac.lk")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registration Denied: Use @students.nsbm.ac.lk email"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    if (!verifyOtp(email: email, otp: otp)) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("OTP or Email Mismatch"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'initials': initialsController.text.trim(),
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'surname': surnameController.text.trim(),
        'student_id': studentIdController.text.trim(),
        'birthday': dateController.text.trim(),
        'batch': dropdown1Value,
        'faculty': dropdown3Value,
        'degree': dropdown2Value,
        'created_at': Timestamp.now(),
      });
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registration Success"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      });
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Registration Error"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 60),
            Image.asset('assets/images/nsbm_logo.png', width: 150),
            SizedBox(height: 30),
            Text(
              "Enter Your Details!",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: AppFonts.main,
              ),
            ),
            SizedBox(height: 40),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: "University Email Address",
                border: OutlineInputBorder(),
                suffix: isCountingDown
                    ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("${secondsRemaining}s", style: TextStyle(color: Colors.grey)),
                )
                    : isSendingOtp
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
                    : TextButton(
                  onPressed: () async {
                    String email = emailController.text.trim();
                    if (email.isEmpty) return;

                    if (!email.endsWith("@students.nsbm.ac.lk")) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Invalid Email: Use @students.nsbm.ac.lk"),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return; 
                    }

                    setState(() => isSendingOtp = true);
                    await sendOtp(email: email);
                    setState(() => isSendingOtp = false);
                    startCountdown();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("OTP Sent to Your Email"),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: EdgeInsets.all(10),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text("Send OTP", style: TextStyle(color: AppColors.primary, fontSize: 15)),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: "Password",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: _isPasswordVisible ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                hintText: "Confirm Password",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: _isConfirmPasswordVisible ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(controller: otpController, decoration: InputDecoration(hintText: "Enter OTP sent to your Email", border: OutlineInputBorder())),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: initialsController, decoration: InputDecoration(hintText: "Initials", border: OutlineInputBorder()))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: surnameController, decoration: InputDecoration(hintText: "Surname", border: OutlineInputBorder()))),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: firstNameController, decoration: InputDecoration(hintText: "First Name", border: OutlineInputBorder()))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: lastNameController, decoration: InputDecoration(hintText: "Last Name", border: OutlineInputBorder()))),
              ],
            ),
            SizedBox(height: 10),
            TextField(controller: studentIdController, decoration: InputDecoration(hintText: "Student ID", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(
              controller: dateController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Select Your Birthday",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    dateController.text = "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
                  });
                }
              },
            ),
            SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                List<DropdownMenuItem<String>> batchItems = [];
                if (snapshot.hasData) {
                  batchItems = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']));
                  }).toList();
                }
                return DropdownButton<String>(
                  hint: Text("Select Batch"),
                  value: batchItems.any((item) => item.value == dropdown1Value) ? dropdown1Value : null,
                  isExpanded: true,
                  items: batchItems,
                  onChanged: (value) => setState(() => dropdown1Value = value),
                );
              },
            ),
            SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('faculties').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                List<DropdownMenuItem<String>> facultyItems = [];
                if (snapshot.hasData) {
                  facultyItems = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']));
                  }).toList();
                }
                return DropdownButton<String>(
                  hint: Text("Select Faculty"),
                  value: facultyItems.any((item) => item.value == dropdown3Value) ? dropdown3Value : null,
                  isExpanded: true,
                  items: facultyItems,
                  onChanged: (value) {
                    setState(() {
                      dropdown3Value = value;
                      dropdown2Value = null; 
                    });
                  },
                );
              },
            ),
            SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: dropdown3Value == null
                  ? FirebaseFirestore.instance.collection('degrees').orderBy('name').snapshots()
                  : FirebaseFirestore.instance.collection('degrees').where('faculty', isEqualTo: dropdown3Value).snapshots(),
              builder: (context, snapshot) {
                List<DropdownMenuItem<String>> degreeItems = [];
                if (snapshot.hasData) {
                  degreeItems = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']));
                  }).toList();
                }
                return DropdownButton<String>(
                  hint: Text(dropdown3Value == null ? "Select Faculty First" : "Select Your Degree"),
                  value: degreeItems.any((item) => item.value == dropdown2Value) ? dropdown2Value : null,
                  isExpanded: true,
                  items: degreeItems,
                  onChanged: dropdown3Value == null ? null : (value) => setState(() => dropdown2Value = value),
                );
              },
            ),
            SizedBox(height: 30),

            ElevatedButton(
              onPressed: isLoading ? null : () async => await registerUser(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(190, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text("Register", style: TextStyle(fontSize: 18)),
            ),
            SizedBox(height: 30)
          ],
        ),
      ),
    );
  }
}
