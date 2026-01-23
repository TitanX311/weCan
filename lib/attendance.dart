import 'package:WeCan/volunteer_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class Attendance extends StatefulWidget {
  const Attendance({super.key});

  @override
  State<Attendance> createState() => _AttendanceState();
}

class _AttendanceState extends State<Attendance> {
  final _listStateKey = GlobalKey<_VolunteerAttendanceListState>();
  DateTime _selectedDate = DateTime.now();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = !connectivityResult.contains(ConnectivityResult.none);
    });
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        final isConnected = !result.contains(ConnectivityResult.none);
        if (isConnected != _isOnline) {
          setState(() {
            _isOnline = isConnected;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isConnected
                      ? '✓ Connected to internet'
                      : '✗ No internet connection',
                ),
                backgroundColor: isConnected ? Colors.green : Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Reload data when connection is restored
          if (isConnected) {
            _listStateKey.currentState?._loadData();
          }
        }
      },
    );
  }

  void _pickDate() async {
    if (!_isOnline) {
      _showNoInternetDialog();
      return;
    }

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
    if (!_isOnline) {
      _showNoInternetDialog();
      return;
    }

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
          onSelect: (name) async {
            await listState.addVolunteer(name);
          },
        );
      },
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('No Internet'),
          ],
        ),
        content: const Text(
          'Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
          // Connection Status Indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.white.withOpacity(0.2)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              isOnline: _isOnline,
            ),
          ),
        ],
      ),
    );
  }
}

class VolunteerAttendanceList extends StatefulWidget {
  final DateTime selectedDate;
  final bool isOnline;

  const VolunteerAttendanceList({
    super.key,
    required this.selectedDate,
    required this.isOnline,
  });

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

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    if (!widget.isOnline) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      await getAllVolunteers();

      final scheduled = await _getScheduledVolunteers(widget.selectedDate);
      final attendance = await _getAttendance(widget.selectedDate);

      if (!mounted) return;

      setState(() {
        _scheduledVolunteers = scheduled;
        _attendanceMap = attendance;
        _updateDisplayList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    // Update volunteerPhoneMap for volunteers who have attendance
    for (final name in raw.keys) {
      if (allVolunteerPhoneMap.containsKey(name) &&
          !volunteerPhoneMap.containsKey(name)) {
        volunteerPhoneMap[name] = allVolunteerPhoneMap[name]!;
      }
    }

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
    if (!widget.isOnline) {
      _showNoInternetSnackbar();
      return;
    }

    final phone = allVolunteerPhoneMap[name];
    if (phone == null) {
      print('Error: Phone not found for $name');
      return;
    }

    final dateKey = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
    final prevStatus = _attendanceMap[name] ?? AttendanceStatus.none;

    if (prevStatus == newStatus) return;

    // Update local state first for immediate UI feedback
    setState(() {
      _attendanceMap[name] = newStatus;
    });

    try {
      final attendanceRef =
          FirebaseFirestore.instance.collection('attendance').doc(dateKey);

      if (newStatus == AttendanceStatus.none) {
        // Remove the volunteer from attendance document
        await attendanceRef.update({
          'attendance.$name': FieldValue.delete(),
        });
      } else {
        // Set present or absent
        await attendanceRef.set({
          'attendance': {
            name: newStatus == AttendanceStatus.present ? 'present' : 'absent'
          }
        }, SetOptions(merge: true));
      }

      await _updateProfileAttendance(
        name: name,
        phone: phone,
        previous: prevStatus,
        current: newStatus,
      );
    } catch (e) {
      print('Error updating attendance: $e');
      // Revert state on error
      setState(() {
        _attendanceMap[name] = prevStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNoInternetSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No internet connection. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
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

    allVolunteerPhoneMap = map;
    return map.keys.toList()..sort();
  }

  Future<void> addVolunteer(String name) async {
    if (!widget.isOnline) {
      _showNoInternetSnackbar();
      return;
    }

    if (_displayVolunteers.contains(name)) return;

    final phone = allVolunteerPhoneMap[name];
    if (phone == null) return;

    try {
      // First, save to database
      final dateKey = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
      final attendanceRef =
          FirebaseFirestore.instance.collection('attendance').doc(dateKey);

      await attendanceRef.set({
        'attendance': {name: 'present'}
      }, SetOptions(merge: true));

      await _updateProfileAttendance(
        name: name,
        phone: phone,
        previous: AttendanceStatus.none,
        current: AttendanceStatus.present,
      );

      // Then update local state
      setState(() {
        volunteerPhoneMap[name] = phone;
        _attendanceMap[name] = AttendanceStatus.present;
        _updateDisplayList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add volunteer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

      // From none to present
      if (previous == AttendanceStatus.none &&
          current == AttendanceStatus.present) {
        pDelta = 1;
      }

      // From none to absent
      if (previous == AttendanceStatus.none &&
          current == AttendanceStatus.absent) {
        aDelta = 1;
      }

      // From present to absent
      if (previous == AttendanceStatus.present &&
          current == AttendanceStatus.absent) {
        pDelta = -1;
        aDelta = 1;
      }

      // From absent to present
      if (previous == AttendanceStatus.absent &&
          current == AttendanceStatus.present) {
        aDelta = -1;
        pDelta = 1;
      }

      // From present to none (UNDO)
      if (previous == AttendanceStatus.present &&
          current == AttendanceStatus.none) {
        pDelta = -1;
      }

      // From absent to none (UNDO)
      if (previous == AttendanceStatus.absent &&
          current == AttendanceStatus.none) {
        aDelta = -1;
      }

      if (!snap.exists) {
        // Only create if we're marking present or absent, not for undo to none
        if (current != AttendanceStatus.none) {
          tx.set(
              ref,
              VolunteerProfile(
                name: name,
                phone: phone,
                presentDays: pDelta > 0 ? pDelta : 0,
                absentDays: aDelta > 0 ? aDelta : 0,
                attendanceLog: {dateKey: current == AttendanceStatus.present},
              ).toMap());
        }
        return;
      }

      // Update existing profile
      final Map<String, dynamic> updates = {};

      if (current == AttendanceStatus.none) {
        // Remove from attendance log
        updates['attendanceLog.$dateKey'] = FieldValue.delete();
      } else {
        // Update attendance log
        updates['attendanceLog.$dateKey'] = current == AttendanceStatus.present;
      }

      if (pDelta != 0) updates['presentDays'] = FieldValue.increment(pDelta);
      if (aDelta != 0) updates['absentDays'] = FieldValue.increment(aDelta);

      tx.update(ref, updates);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!widget.isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_displayVolunteers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No volunteers scheduled for this day.\nUse the + button to add a volunteer.\n\nPull down to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.green,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _displayVolunteers.length,
        itemBuilder: (context, index) {
          final String volunteer = _displayVolunteers[index];
          final phone = allVolunteerPhoneMap[volunteer] ?? "Unknown";
          final volunteerName = "$volunteer - $phone";

          final status = _attendanceMap[volunteer] ?? AttendanceStatus.none;

          final isPresent = status == AttendanceStatus.present;
          final isAbsent = status == AttendanceStatus.absent;
          final isNone = status == AttendanceStatus.none;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isPresent
                  ? BorderSide(color: Colors.green.shade400, width: 1.2)
                  : isAbsent
                      ? BorderSide(color: Colors.red.shade400, width: 1.2)
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

                  // PRESENT Button
                  GestureDetector(
                    onTap: () =>
                        _toggleAttendance(volunteer, AttendanceStatus.present),
                    child: CircleAvatar(
                      backgroundColor: isPresent
                          ? Colors.green
                          : Colors.green.withOpacity(0.2),
                      child: Text(
                        "P",
                        style: TextStyle(
                          color: isPresent ? Colors.white : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ABSENT Button
                  GestureDetector(
                    onTap: () =>
                        _toggleAttendance(volunteer, AttendanceStatus.absent),
                    child: CircleAvatar(
                      backgroundColor:
                          isAbsent ? Colors.red : Colors.red.withOpacity(0.2),
                      child: Text(
                        "A",
                        style: TextStyle(
                          color: isAbsent ? Colors.white : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // UNDO Button (only show when marked)
                  if (!isNone)
                    GestureDetector(
                      onTap: () =>
                          _toggleAttendance(volunteer, AttendanceStatus.none),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        child: Icon(
                          Icons.undo,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AddVolunteerDialog extends StatefulWidget {
  final List<String> volunteers;
  final Future<void> Function(String) onSelect;

  const AddVolunteerDialog({
    super.key,
    required this.volunteers,
    required this.onSelect,
  });

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
                    onTap: () async {
                      await widget.onSelect(volunteerName);
                      if (mounted) Navigator.pop(context);
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
