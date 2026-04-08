import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';
import '../widgets/event_widget.dart';
import '../theme.dart';

class EventCalendarPage extends StatefulWidget {
  const EventCalendarPage({super.key});

  @override
  State<EventCalendarPage> createState() => _EventCalendarPageState();
}

class _EventCalendarPageState extends State<EventCalendarPage> {
  final EventService _eventService = EventService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  // We no longer need _loadEventDates() or initState for the list
  // because the StreamBuilder handles it now.
  List<String> _highlightedDates = [];

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String formattedSelectedDate = DateFormat('d/M/yyyy').format(_selectedDay ?? now);

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            children: [
              // STREAMBUILDER FOR LIVE CALENDAR DOTS
              StreamBuilder<List<String>>(
                stream: _eventService.getAllEventDatesStream(),
                builder: (context, snapshot) {
                  // This updates the local list whenever Firestore changes
                  _highlightedDates = snapshot.data ?? [];

                  return Card(
                    color: AppColors.primary.withOpacity(0.1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: DateTime(now.year - 1, now.month, now.day),
                        lastDay: DateTime(now.year + 1, now.month, now.day),
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
                          weekendTextStyle: const TextStyle(color: Colors.redAccent),
                          selectedDecoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(color: Colors.white),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            String dateStr = DateFormat('d/M/yyyy').format(day);
                            if (_highlightedDates.contains(dateStr)) {
                              return Container(
                                margin: const EdgeInsets.all(4.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.secondary, width: 1),
                                ),
                                child: Text(
                                  day.day.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 15),

              Text(
                "Events for $formattedSelectedDate",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              EventWidget.buildEventList(_eventService.getEventsByDate(formattedSelectedDate)),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
