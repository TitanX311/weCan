import 'package:WeCan/volunteer_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class Attendance extends StatefulWidget {
  const Attendance({super.key});

  @override
  State<Attendance> createState() => _AttendanceState();
}

class _AttendanceState extends State<Attendance> {
  final _listStateKey = GlobalKey<_VolunteerAttendanceListState>();
  DateTime _selectedDate = DateTime.now();

  void _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddVolunteerDialog() async {
    final listState = _listStateKey.currentState;
    if (listState == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final allVolunteers = await listState.getAllVolunteers();
    final displayedVolunteers = listState.displayedVolunteers;

    Navigator.pop(context); // Dismiss loading indicator

    final selectableVolunteers =
        allVolunteers.where((v) => !displayedVolunteers.contains(v)).toList();

    if (!mounted) return;

    if (selectableVolunteers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All volunteers are already in the list.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AddVolunteerDialog(
          volunteers: selectableVolunteers,
          onSelect: (name) {
            listState.addVolunteer(name);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mark Attendance',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Icon(Icons.date_range, color: Colors.green.shade700),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1.5,
          ),
          Expanded(
            child: VolunteerAttendanceList(
              key: _listStateKey,
              selectedDate: _selectedDate,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVolunteerDialog,
        backgroundColor: Colors.green,
        tooltip: 'Add Volunteer',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class VolunteerAttendanceList extends StatefulWidget {
  final DateTime selectedDate;

  const VolunteerAttendanceList({super.key, required this.selectedDate});

  @override
  State<VolunteerAttendanceList> createState() =>
      _VolunteerAttendanceListState();
}

class _VolunteerAttendanceListState extends State<VolunteerAttendanceList> {
  bool _isLoading = true;
  List<String> _scheduledVolunteers = [];
  Set<String> _presentVolunteers = {};
  List<String> _displayVolunteers = [];

  List<String> get displayedVolunteers => _displayVolunteers;

  @override
  void didUpdateWidget(covariant VolunteerAttendanceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final scheduled = await _getScheduledVolunteers(widget.selectedDate);
    final present = await _getPresentVolunteers(widget.selectedDate);

    if (mounted) {
      setState(() {
        _scheduledVolunteers = scheduled;
        _presentVolunteers = present;
        _updateDisplayList();
        _isLoading = false;
      });
    }
  }

  void _updateDisplayList() {
    _displayVolunteers =
        {..._scheduledVolunteers, ..._presentVolunteers}.toList()..sort();
  }

  Future<List<String>> _getScheduledVolunteers(DateTime date) async {
    final dayName = DateFormat('EEEE').format(date).toLowerCase();

    final doc = await FirebaseFirestore.instance
        .collection('volunteers')
        .doc(dayName)
        .get();

    if (!doc.exists || !doc.data()!.containsKey('volunteers')) {
      return [];
    }

    final rawList = List<String>.from(doc.data()!['volunteers']);

    // Build phone map
    volunteerPhoneMap = _parseVolunteerPhoneMap(rawList);

    /// volunteerPhoneMap = {
    ///   "name":"ph no",
    /// }

    // Return only names for UI
    return volunteerPhoneMap.keys.toList();
  }

  Future<Set<String>> _getPresentVolunteers(DateTime date) async {
    final dateString = DateFormat('dd-MM-yyyy').format(date);
    final doc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(dateString)
        .get();
    if (doc.exists && doc.data()!.containsKey('presentVolunteers')) {
      return Set<String>.from(doc.data()!['presentVolunteers']);
    }
    return {};
  }

  Map<String, String> _parseVolunteerPhoneMap(List<String> rawList) {
    final Map<String, String> map = {};

    for (final entry in rawList) {
      // Supports "name | phone" and "name - phone"
      final parts = entry.contains('|')
          ? entry.split('|')
          : entry.contains('-')
              ? entry.split('-')
              : [];

      if (parts.length == 2) {
        final name = parts[0].trim();
        final phone = parts[1].trim();
        map[name] = phone;
      }
    }

    return map;
  }

  Map<String, String> volunteerPhoneMap = {};

  Future<void> _toggleAttendance(String volunteerName, bool isPresent) async {
    final phone = volunteerPhoneMap[volunteerName];
    if (phone == null) return;

    final originalPresentState = Set<String>.from(_presentVolunteers);

    setState(() {
      if (isPresent) {
        _presentVolunteers.add(volunteerName);
      } else {
        _presentVolunteers.remove(volunteerName);
      }
      _updateDisplayList();
    });

    final dateString = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
    final dayName =
        DateFormat('EEEE').format(widget.selectedDate).toLowerCase();

    final attendanceRef =
        FirebaseFirestore.instance.collection('attendance').doc(dateString);

    try {
      // Update attendance collection
      if (isPresent) {
        await attendanceRef.set({
          'dayName': dayName,
          'presentVolunteers': FieldValue.arrayUnion([volunteerName]),
        }, SetOptions(merge: true));
      } else {
        await attendanceRef.update({
          'presentVolunteers': FieldValue.arrayRemove([volunteerName]),
        });
      }

      // ✅ Update profile summary
      await _updateProfileAttendance(
        name: volunteerName,
        phone: phone,
        isPresent: isPresent,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating attendance: $e')),
      );

      setState(() {
        _presentVolunteers = originalPresentState;
        _updateDisplayList();
      });
    }
  }

  Future<List<String>> getAllVolunteers() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('volunteers').get();

    final Map<String, String> map = {};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('volunteers')) {
        map.addAll(
          _parseVolunteerPhoneMap(List<String>.from(data['volunteers'])),
        );
      }
    }
    return map.keys.toList()..sort();
  }

  void addVolunteer(String name) {
    _toggleAttendance(name, true);
  }

  Future<void> _updateProfileAttendance({
    required String name,
    required String phone,
    required bool isPresent,
  }) async {
    final dateKey = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
    final docRef = FirebaseFirestore.instance.collection('profiles').doc(phone);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);

      if (!snap.exists) {
        tx.set(
            docRef,
            VolunteerProfile(
              name: name,
              phone: phone,
              presentDays: isPresent ? 1 : 0,
              absentDays: isPresent ? 0 : 1,
              attendanceLog: {dateKey: isPresent},
            ).toMap());
        return;
      }

      final data = snap.data()!;
      final log = Map<String, dynamic>.from(data['attendanceLog'] ?? {});
      final prev = log[dateKey];

      if (prev == isPresent) return; // ✅ no double count

      tx.update(docRef, {
        'attendanceLog.$dateKey': isPresent,
        if (prev == null)
          isPresent ? 'presentDays' : 'absentDays': FieldValue.increment(1)
        else ...{
          'presentDays': FieldValue.increment(isPresent ? 1 : -1),
          'absentDays': FieldValue.increment(isPresent ? -1 : 1),
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_displayVolunteers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No volunteers scheduled for this day.\nUse the + button to add a volunteer.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, color: Colors.grey.shade700, height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _displayVolunteers.length,
      itemBuilder: (context, index) {
        final String volunteer = _displayVolunteers[index];
        final String volunteerName =
            "$volunteer - ${volunteerPhoneMap[volunteer]!}";
        final isPresent = _presentVolunteers.contains(volunteer);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isPresent
                ? BorderSide(color: Colors.green.shade400, width: 1.2)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Volunteer Name
                Expanded(
                  child: Text(
                    volunteerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),

                // PRESENT BUTTON
                GestureDetector(
                  onTap: isPresent
                      ? null
                      : () => _toggleAttendance(volunteer, true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPresent
                          ? Colors.green
                          : Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "P",
                      style: TextStyle(
                        color: isPresent ? Colors.white : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ABSENT BUTTON
                GestureDetector(
                  onTap: !isPresent
                      ? null
                      : () => _toggleAttendance(volunteerName, false),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: !isPresent
                          ? Colors.red
                          : Colors.red.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "A",
                      style: TextStyle(
                        color: !isPresent ? Colors.white : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddVolunteerDialog extends StatefulWidget {
  final List<String> volunteers;
  final Function(String) onSelect;

  const AddVolunteerDialog(
      {super.key, required this.volunteers, required this.onSelect});

  @override
  State<AddVolunteerDialog> createState() => _AddVolunteerDialogState();
}

class _AddVolunteerDialogState extends State<AddVolunteerDialog> {
  String _searchQuery = '';
  late List<String> _filteredVolunteers;

  @override
  void initState() {
    super.initState();
    _filteredVolunteers = widget.volunteers;
  }

  void _filterVolunteers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredVolunteers = widget.volunteers
          .where((v) => v.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Volunteer'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: _filterVolunteers,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredVolunteers.length,
                itemBuilder: (context, index) {
                  final volunteerName = _filteredVolunteers[index];
                  return ListTile(
                    title: Text(volunteerName),
                    onTap: () {
                      widget.onSelect(volunteerName);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
