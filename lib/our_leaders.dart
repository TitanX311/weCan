import 'package:WeCan/db_services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'leader_form.dart';
import 'leaders_details.dart';

class OurLeadersScreen extends StatefulWidget {
  const OurLeadersScreen({super.key});

  @override
  State<OurLeadersScreen> createState() => _OurLeadersScreenState();
}

class _OurLeadersScreenState extends State<OurLeadersScreen> {
  final CollectionReference leadersCollection =
      FirebaseFirestore.instance.collection('leaders');
  bool isLoggedIn = false;

  bool _isLeaderEdit = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      isLoggedIn = user != null;
    });
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await isUserAdmin();

    if (!mounted) return;

    setState(() {
      _isLeaderEdit = isAdmin;
    });
  }

  Future<bool> isUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    print(user);

    if (user == null || user.email == null) {
      return false;
    }

    final email = user.email!.trim().toLowerCase();

    final doc = await FirebaseFirestore.instance
        .collection('permissions')
        .doc('leader_edit')
        .get();

    if (!doc.exists) return false;

    final List admins = doc.data()?['admin_list'] ?? [];
    return admins.contains(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "🚀 Our Leaders",
          style: GoogleFonts.playfairDisplay(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 3,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: leadersCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.teal));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No leaders yet 🥺",
                style: GoogleFonts.roboto(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          var leaders = snapshot.data!.docs;
          leaders.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            if (dataA['position'] == 'President' &&
                dataB['position'] != 'President') {
              return -1;
            } else if (dataA['position'] != 'President' &&
                dataB['position'] == 'President') {
              return 1;
            }
            int yearA = int.tryParse(dataA['year']?.toString() ?? "0") ?? 0;
            int yearB = int.tryParse(dataB['year']?.toString() ?? "0") ?? 0;

            return yearB.compareTo(yearA); // Descending order
          });

          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: leaders.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 cards in each row
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7, // 🔹 Fixed overflow issue
              ),
              itemBuilder: (context, index) {
                var leader = leaders[index];
                var data = leader.data() as Map<String, dynamic>;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaderDetailsScreen(
                            leaderData: data, leaderId: leader.id),
                      ),
                    );
                  },
                  child: Hero(
                    tag: data['image_url'] ?? '',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.white,
                        border: Border.all(color: Colors.teal, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8), // Adjusted padding
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.network(
                                data['image_url'] ?? "",
                                height: 70, // 🔹 Reduced image size
                                width: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.person,
                                      size: 60, color: Colors.grey);
                                },
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              data['name'] ?? "Unknown",
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              textAlign: TextAlign.center,
                              maxLines: 1, // 🔹 Prevents overflow
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              // Adjusted padding
                              decoration: BoxDecoration(
                                color: _getRoleColor(data['position'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                data['position'] ?? "Volunteer",
                                style: GoogleFonts.lobster(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _getRoleColor(data['position'])),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Year: ${data['year']}",
                              style: GoogleFonts.roboto(
                                  fontSize: 11, color: Colors.black54),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _isLeaderEdit
          ? FloatingActionButton(
              backgroundColor: Colors.teal,
              elevation: 5,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LeaderFormScreen()),
                );
              },
            )
          : null,
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'President':
        return Colors.orangeAccent;
      default:
        return Colors.teal;
    }
  }
}
