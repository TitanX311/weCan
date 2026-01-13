import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceDetailsPage extends StatefulWidget {
  const AttendanceDetailsPage({super.key});

  @override
  State<AttendanceDetailsPage> createState() => _AttendanceDetailsPageState();
}

class _AttendanceDetailsPageState extends State<AttendanceDetailsPage> {
  late Future<List<String>> _allVolunteersFuture;

  @override
  void initState() {
    super.initState();
    _allVolunteersFuture = _getAllVolunteers();
  }

  Future<List<String>> _getAllVolunteers() async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('volunteers').get();
    final Set<String> allVolunteers = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('volunteers')) {
        allVolunteers.addAll(List<String>.from(data['volunteers']));
      }
    }
    return allVolunteers.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Text(
          'Volunteer Attendance Stats',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<String>>(
        future: _allVolunteersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No volunteers found.'));
          }

          final volunteers = snapshot.data!;

          return ListView.builder(
            itemCount: volunteers.length,
            itemBuilder: (context, index) {
              final volunteerName = volunteers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(volunteerName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VolunteerStatsPage(volunteerName: volunteerName),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VolunteerStatsPage extends StatefulWidget {
  final String volunteerName;

  const VolunteerStatsPage({super.key, required this.volunteerName});

  @override
  State<VolunteerStatsPage> createState() => _VolunteerStatsPageState();
}

class _VolunteerStatsPageState extends State<VolunteerStatsPage> {
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _calculateStats();
  }

  Future<Map<String, int>> _calculateStats() async {
    // 1. Find all days the volunteer is scheduled
    final volunteerScheduleSnapshot = await FirebaseFirestore.instance
        .collection('volunteers')
        .where('volunteers', arrayContains: widget.volunteerName)
        .get();

    final scheduledDays =
        volunteerScheduleSnapshot.docs.map((doc) => doc.id).toList();

    // 2. Get all attendance records
    final attendanceSnapshot =
        await FirebaseFirestore.instance.collection('attendance').get();

    int totalScheduled = 0;
    int totalPresent = 0;

    for (var attendanceDoc in attendanceSnapshot.docs) {
      final data = attendanceDoc.data();
      final dayName = data['dayName']?.toString().toLowerCase();
      final presentVolunteers =
          List<String>.from(data['presentVolunteers'] ?? []);

      // This logic assumes that if an attendance document exists for a day,
      // it counts as a scheduled day for everyone scheduled on that day of the week.
      // This is a simplification and might need refinement based on exact requirements.
      if (dayName != null && scheduledDays.contains(dayName)) {
        totalScheduled++;
        if (presentVolunteers.contains(widget.volunteerName)) {
          totalPresent++;
        }
      }
    }

    // This is a simplified calculation. For a more accurate "totalScheduled", you'd need to count
    // the number of actual dates that have passed for each scheduled day of the week since the
    // volunteer was added. This current logic just counts the number of attendance records
    // that have been created for the days they are scheduled.

    return {
      'totalScheduled': totalScheduled,
      'totalPresent': totalPresent,
      'totalAbsent': totalScheduled - totalPresent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.volunteerName,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No stats available.'));
          }

          final stats = snapshot.data!;
          final totalScheduled = stats['totalScheduled'] ?? 0;
          final totalPresent = stats['totalPresent'] ?? 0;
          final totalAbsent = stats['totalAbsent'] ?? 0;
          final percentage =
              totalScheduled > 0 ? (totalPresent / totalScheduled) * 100 : 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                StatCard(
                  label: 'Total Scheduled Days',
                  value: totalScheduled.toString(),
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                ),
                StatCard(
                  label: 'Present',
                  value: totalPresent.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                StatCard(
                  label: 'Absent',
                  value: totalAbsent.toString(),
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
                StatCard(
                  label: 'Presence Percentage',
                  value: '${percentage.toStringAsFixed(1)}%',
                  icon: Icons.pie_chart,
                  color: Colors.orange,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
