import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:WeCan/volunteer_model.dart';

/// =======================================================
/// ATTENDANCE DETAILS PAGE
/// =======================================================
class AttendanceDetailsPage extends StatefulWidget {
  const AttendanceDetailsPage({super.key});

  @override
  State<AttendanceDetailsPage> createState() => _AttendanceDetailsPageState();
}

class _AttendanceDetailsPageState extends State<AttendanceDetailsPage> {
  late Future<List<VolunteerProfile>> _profilesFuture;
  List<VolunteerProfile> _allProfiles = [];
  List<VolunteerProfile> _filteredProfiles = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profilesFuture = _fetchProfiles();
    _searchController.addListener(_filterProfiles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<VolunteerProfile>> _fetchProfiles() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('profiles').get();

    final profiles = snapshot.docs.map((doc) {
      final data = doc.data();
      return VolunteerProfile(
        name: data['name'] ?? '',
        phone: data['phone'] ?? doc.id,
        email: data['email'] ?? '',
        attendanceLog: Map<String, bool>.from(data['attendanceLog'] ?? {}),
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _allProfiles = profiles;
      _filteredProfiles = profiles;
    });

    return profiles;
  }

  void _filterProfiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProfiles = _allProfiles;
      } else {
        _filteredProfiles = _allProfiles.where((profile) {
          return profile.name.toLowerCase().contains(query) ||
              profile.phone.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Attendance Stats',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade200),
                ),
                filled: true,
                fillColor: Colors.green.shade50,
              ),
            ),
          ),

          // List of Volunteers
          Expanded(
            child: FutureBuilder<List<VolunteerProfile>>(
              future: _profilesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No volunteers found.'));
                }

                if (_filteredProfiles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No volunteers found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: _filteredProfiles.length,
                  itemBuilder: (context, index) {
                    final profile = _filteredProfiles[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          profile.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(profile.phone),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VolunteerStatsPage(profile: profile),
                            ),
                          );
                        },
                      ),
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

/// =======================================================
/// VOLUNTEER STATS PAGE
/// =======================================================
class VolunteerStatsPage extends StatelessWidget {
  final VolunteerProfile profile;

  const VolunteerStatsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final int totalMarked = profile.presentDays + profile.absentDays;

    final double percentage =
        totalMarked > 0 ? (profile.presentDays / totalMarked) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile.name,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StatCard(
              label: 'Total Marked Days',
              value: totalMarked.toString(),
              icon: Icons.calendar_today,
              color: Colors.blue,
            ),
            StatCard(
              label: 'Present',
              value: profile.presentDays.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            StatCard(
              label: 'Absent',
              value: profile.absentDays.toString(),
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
      ),
    );
  }
}

/// =======================================================
/// STAT CARD
/// =======================================================
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
      elevation: 3,
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
