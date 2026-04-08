import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:nsbm_connect/screens/announcements_page.dart';
import 'login_page.dart';
import '../theme.dart';
import '../services/weather_service.dart';
import '../services/timetable_service.dart';
import '../widgets/weather_widget.dart';
import 'timetable_page.dart';
import 'map_page.dart';
import 'event_calendar_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import '../widgets/event_widget.dart';
import '../services/event_service.dart';
import '../widgets/message_card_widget.dart';
import 'package:nsbm_connect/widgets/news_carousel_widget.dart';

class Dashboard extends StatefulWidget {
  final String uid;
  const Dashboard({super.key, required this.uid});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final WeatherService _weatherService = WeatherService();
  final TimetableService _timetableService = TimetableService();
  final EventService _eventService = EventService();

  int _selectedIndex = 0;
  Map<String, dynamic>? userData;
  late Future<void> _initDataFuture;

  late List<Widget> _pages;
  bool _isPagesInitialized = false;

  @override
  void initState() {
    super.initState();
    _initDataFuture = _setupDashboard();
  }

  Future<void> _setupDashboard() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      if (doc.exists) {
        userData = doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }

    if (mounted) {
      setState(() {
        _pages = [
          _buildHomeContent(),      
          const TimetablePage(),    
          const MapPage(),          
          const EventCalendarPage(), 
          const CommunityPage(),     
          const ProfilePage(),       
        ];
        _isPagesInitialized = true;
      });
    }
  }

  Widget _buildHomeContent() {
    String todayDateISO = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),

            WeatherWidget(userData: userData, weatherService: _weatherService),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Time Table", style: TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(DateFormat('dd-MMMM-yyyy').format(DateTime.now()), style: TextStyle(color: AppColors.secondary, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),

            _timetableService.displayTodayTimetable(todayDateISO, widget.uid),
            const SizedBox(height: 8),

            Text("Upcoming Events", style: TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            EventWidget.buildEventList(
              _eventService.getUpcomingThreeDaysEvents(),
              emptyMessage: "No events scheduled for the next 3 days.",
            ),

            Text("Latest Announcements", style: TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDashboardAnnouncements(),

            const NewsCarousel(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardAnnouncements() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();
        var dataMap = userSnap.data!.data() as Map<String, dynamic>? ?? {};

        String userBatch = dataMap['batch'] ?? "";
        String userFaculty = dataMap['faculty'] ?? "";
        String userDegree = dataMap['degree'] ?? "";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text("Error loading announcements");
            if (!snapshot.hasData) return const SizedBox();

            final filtered = snapshot.data!.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String mode = data['mode'] ?? "";
              List recipients = data['recipients'] ?? [];

              if (mode == 'all') return true;
              if (mode == 'specific') return recipients.any((r) => r['uid'] == user.uid);
              if (mode == 'group') {
                return recipients.any((r) {
                  bool batchMatch = r['batch'] == "All Batches" || r['batch'] == userBatch;
                  bool facultyMatch = r['faculty'] == "All Faculties" || r['faculty'] == userFaculty;
                  bool degreeMatch = r['degree'] == "All Degrees" || r['degree'] == userDegree;
                  return batchMatch && facultyMatch && degreeMatch;
                });
              }
              return false;
            }).take(3).toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("No recent announcements")),
              );
            }

            return Column(
              children: filtered.map((doc) => MessageCard(
                  announcementId: doc.id,
                  data: doc.data() as Map<String, dynamic>
              )).toList(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPagesInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        leadingWidth: 95,
        leading: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: Image.asset('assets/images/nsbm_logo.png', fit: BoxFit.contain),
        ),
        title: Text("NSBM Connect", style: TextStyle(color: AppColors.primary, fontSize: 23, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign),
            onPressed: () async {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AnnouncementsPage()));
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: "Timetable"),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: "Map"),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: "Hub"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }
}
