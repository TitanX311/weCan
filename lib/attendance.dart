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
          // IconButton(
          //   icon: const Icon(Icons.calendar_today),
          //   onPressed: _pickDate,
          // ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddVolunteerDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickDate,
            child: Padding(
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

enum AttendanceStatus { none, present, absent }

class _VolunteerAttendanceListState extends State<VolunteerAttendanceList> {
  bool _isLoading = true;
  List<String> _scheduledVolunteers = [];
  Map<String, AttendanceStatus> _attendanceMap = {};
  List<String> _displayVolunteers = [];

  Map<String, String> allVolunteerPhoneMap = {};
  Map<String, String> volunteerPhoneMap = {}; // for displayed only

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
    final attendance = await _getAttendance(widget.selectedDate);

    if (!mounted) return;

    setState(() {
      _scheduledVolunteers = scheduled;
      _attendanceMap = attendance;
      _updateDisplayList();
      _isLoading = false;
    });
  }

  void _updateDisplayList() {
    _displayVolunteers = {
      ..._scheduledVolunteers,
      ..._attendanceMap.keys,
    }.toList()
      ..sort();
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

  Future<Map<String, AttendanceStatus>> _getAttendance(DateTime date) async {
    final dateKey = DateFormat('dd-MM-yyyy').format(date);
    final doc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(dateKey)
        .get();

    if (!doc.exists) return {};

    final raw = Map<String, dynamic>.from(doc.data()!['attendance'] ?? {});
    return raw.map((k, v) {
      return MapEntry(
        k,
        v == 'present' ? AttendanceStatus.present : AttendanceStatus.absent,
      );
    });
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

  Future<void> _toggleAttendance(
    String name,
    AttendanceStatus newStatus,
  ) async {
    final phone = volunteerPhoneMap[name];
    if (phone == null) return;

    final dateKey = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
    final prevStatus = _attendanceMap[name] ?? AttendanceStatus.none;

    if (prevStatus == newStatus) return;

    setState(() {
      _attendanceMap[name] = newStatus;
    });

    final attendanceRef =
        FirebaseFirestore.instance.collection('attendance').doc(dateKey);

    await attendanceRef.set({
      'attendance': {
        name: newStatus == AttendanceStatus.present ? 'present' : 'absent'
      }
    }, SetOptions(merge: true));

    await _updateProfileAttendance(
      name: name,
      phone: phone,
      previous: prevStatus,
      current: newStatus,
    );
  }

  Future<List<String>> getAllVolunteers() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('volunteers').get();

    final Map<String, String> map = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('volunteers')) {
        map.addAll(
          _parseVolunteerPhoneMap(List<String>.from(data['volunteers'])),
        );
      }
    }

    allVolunteerPhoneMap = map; // ✅ STORE GLOBALLY
    return map.keys.toList()..sort();
  }

  Future<void> addVolunteer(String name) async {
    if (_displayVolunteers.contains(name)) return;

    final phone = allVolunteerPhoneMap[name]; // ✅ FIX
    if (phone == null) return;

    setState(() {
      volunteerPhoneMap[name] = phone;
      _displayVolunteers.add(name);
      _displayVolunteers.sort();
      _attendanceMap[name] = AttendanceStatus.present;
    });

    await _toggleAttendance(name, AttendanceStatus.present);
  }

  Future<void> _updateProfileAttendance({
    required String name,
    required String phone,
    required AttendanceStatus previous,
    required AttendanceStatus current,
  }) async {
    final dateKey = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
    final ref = FirebaseFirestore.instance.collection('profiles').doc(phone);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);

      int pDelta = 0;
      int aDelta = 0;

      if (previous == AttendanceStatus.none &&
          current == AttendanceStatus.present) {
        pDelta = 1;
      }

      if (previous == AttendanceStatus.none &&
          current == AttendanceStatus.absent) {
        aDelta = 1;
      }

      if (previous == AttendanceStatus.present &&
          current == AttendanceStatus.absent) {
        pDelta = -1;
        aDelta = 1;
      }

      if (previous == AttendanceStatus.absent &&
          current == AttendanceStatus.present) {
        aDelta = -1;
        pDelta = 1;
      }

      if (!snap.exists) {
        tx.set(
            ref,
            VolunteerProfile(
              name: name,
              phone: phone,
              presentDays: pDelta > 0 ? pDelta : 0,
              absentDays: aDelta > 0 ? aDelta : 0,
              attendanceLog: {dateKey: current == AttendanceStatus.present},
            ).toMap());
        return;
      }

      tx.update(ref, {
        'attendanceLog.$dateKey': current == AttendanceStatus.present,
        if (pDelta != 0) 'presentDays': FieldValue.increment(pDelta),
        if (aDelta != 0) 'absentDays': FieldValue.increment(aDelta),
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
        final phone = volunteerPhoneMap[volunteer] ?? "Unknown";
        final volunteerName = "$volunteer - $phone";

        final status = _attendanceMap[volunteer] ?? AttendanceStatus.none;

        final isPresent = status == AttendanceStatus.present;
        final isAbsent = status == AttendanceStatus.absent;
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

                // PRESENT
                GestureDetector(
                  onTap: () =>
                      _toggleAttendance(volunteer, AttendanceStatus.present),
                  child: CircleAvatar(
                    backgroundColor: isPresent
                        ? Colors.green
                        : Colors.green.withOpacity(0.2),
                    child: const Text("P"),
                  ),
                ),
                const SizedBox(width: 8),
                // ABSENT
                GestureDetector(
                  onTap: () =>
                      _toggleAttendance(volunteer, AttendanceStatus.absent),
                  child: CircleAvatar(
                    backgroundColor:
                        isAbsent ? Colors.red : Colors.red.withOpacity(0.2),
                    child: const Text("A"),
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
