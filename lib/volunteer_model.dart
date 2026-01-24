class VolunteerProfile {
  final String name;
  final String phone;
  final String email;
  final Map<String, bool> attendanceLog;

  const VolunteerProfile({
    required this.name,
    required this.phone,
    this.email = '',
    Map<String, bool>? attendanceLog,
  }) : attendanceLog = attendanceLog ?? const {};

  // Calculate presentDays from attendanceLog
  int get presentDays {
    return attendanceLog.values.where((isPresent) => isPresent).length;
  }

  // Calculate absentDays from attendanceLog
  int get absentDays {
    return attendanceLog.length - presentDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'attendanceLog': attendanceLog,
    };
  }
}
