class VolunteerProfile {
  final String name;
  final String phone;
  final String email;
  final int presentDays;
  final int absentDays;
  final Map<String, bool> attendanceLog;

  const VolunteerProfile({
    required this.name,
    required this.phone,
    this.email = '',
    this.presentDays = 0,
    this.absentDays = 0,
    Map<String, bool>? attendanceLog,
  }) : attendanceLog = attendanceLog ?? const {};

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'attendanceLog': attendanceLog,
    };
  }
}
