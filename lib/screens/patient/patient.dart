import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/patient/book_appointment.dart';
import 'package:medi_slot/screens/patient/view_appointments.dart';
import 'package:medi_slot/screens/patient/manage_appointments.dart';
import 'package:medi_slot/screens/patient/patient_profiles.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'doctor_map_page.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final supabase = Supabase.instance.client;
  String? userName; // Keep this to store the fetched name
  bool isLoading = true;
  int _page = 0;
  Map<String, dynamic>? selectedDoctorInfo;
  Map<String, dynamic>? selectedDoctor;
  late List<Widget> _pages; // Made it non-final to update with fetched userName
  final authService = AuthService();
  List<Map<String, dynamic>> doctors = [];
  bool isDoctorsLoading = true;
  final ScrollController _scrollController = ScrollController();
  int currentEnd = 19;
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMore();
      }
    });
    // Initialize _pages with a placeholder or loading state for the home page initially
    _pages = [
      _buildLoadingHomePage(), // Or a simple Center(child: CircularProgressIndicator())
      // MODIFIED: Use 'preselectedDoctor' to match BookAppointmentPage constructor
      BookAppointmentPage(preselectedDoctor: selectedDoctor),
      const ViewAppointmentsPage(),
      const ManageAppointmentsPage(),
      const ProfilesScreen(),
    ];
    fetchUserNameAndInitializePages();
    // fetchDoctors(); // _loadDoctors calls fetchDoctors, so this might be redundant unless intended.
    // If _loadDoctors already sets the initial list, you might not need this second call here.
    // However, if fetchDoctors in initState has a different purpose (e.g., non-paginated initial small set)
    // and _loadDoctors is for pagination, then it's fine. Review based on your logic.
    // For now, I'll keep it as it was in your snippet.
    fetchDoctors();
  }

  Future<void> _loadDoctors() async {
    final newDoctors = await fetchDoctors(from: 0, to: currentEnd);
    setState(() => doctors = newDoctors);
  }

  Future<void> _loadMore() async {
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);

    final nextStart = currentEnd + 1;
    final nextEnd = currentEnd + 20;
    final newDoctors = await fetchDoctors(from: nextStart, to: nextEnd);

    setState(() {
      doctors.addAll(newDoctors);
      currentEnd = nextEnd;
      isLoadingMore = false;
    });
  }

  // New method to fetch user name and then initialize pages
  Future<void> fetchUserNameAndInitializePages() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            userName = "Patient"; // Default if no user
            _pages[0] = _buildHomePage(userName); // Update home page
            isLoading = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          userName = response['name'] as String? ?? "Patient";
          _pages[0] = _buildHomePage(userName); // Update home page with fetched name
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching username: $e"); // It's good to log the error
        setState(() {
          userName = "Patient"; // Fallback name
          _pages[0] = _buildHomePage(userName); // Update home page
          isLoading = false;
        });
      }
    }
  }

  // Fetch Doctor from DB
  Future<List<Map<String, dynamic>>> fetchDoctors({int from = 0, int to = 19}) async {
    try {
      final response = await supabase
          .from('doctors')
          .select('doctor_id, specialization, profiles(name) ,clinic_locations(clinic_id, clinic_name, address, latitude, longitude)')
          .range(from, to); // fetch doctors in batches

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
      if (mounted) {
        setState(() {
          doctors = data;
          isDoctorsLoading = false;
        });
      }
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
      return [];
    }
  }

  // This is a placeholder for the initial loading state of the home page content
  Widget _buildLoadingHomePage() {
    return const Center(child: CircularProgressIndicator());
  }


  // UNMODIFIED fetchUserName - kept for reference if you prefer the old way, but fetchUserNameAndInitializePages is now primary
  Future<void> fetchUserName() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            userName = "Patient";
            isLoading = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          userName = response['name'] ?? "Patient";
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userName = "Patient";
          isLoading = false;
        });
      }
    }
  }

  Future<void> selectDoctorOnMap() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DoctorMapPage()),
    );

    if (selected != null) {
      final doctorId = selected['doctorId'] ?? selected['doctor_id'];
      final doctorName = selected['doctorName'] ?? selected['doctor_name'] ?? "Unknown";
      final specialization = selected['specialization'] ?? "General";
      final clinicName = selected['clinicName'] ?? selected['clinic_name'] ?? "N/A";
      final address = selected['address'] ?? "N/A";

      if (mounted) {
        setState(() {
          selectedDoctorInfo = {
            'doctorName': doctorName,
            'specialization': specialization,
            'clinicName': clinicName,
            'address': address,
          };
          selectedDoctor = {
            'doctor_id': doctorId,
            'name': doctorName,
            'specialization': specialization,
            'clinicName': clinicName,
            'address': address,
          };
          // MODIFIED: Rebuild the BookAppointmentPage with the new selectedDoctor using the correct parameter
          _pages[1] = BookAppointmentPage(preselectedDoctor: selectedDoctor);
          _page = 1; // Switch to the BookAppointmentPage tab
        });
      }
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing out: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: SafeArea(
        child: isLoading && userName == null
        // Show global loading only if username isn't fetched yet for the initial setup
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
          index: _page,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFFF0F5FF),
        child: CurvedNavigationBar(
          backgroundColor: const Color(0xFFF0F5FF),
          buttonBackgroundColor: Colors.blue.shade700,
          color: Colors.white,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 400),
          height: 60.0,
          index: _page,
          items: const <Widget>[
            Icon(Icons.home, size: 30, color: Colors.black54),
            Icon(Icons.add, size: 30, color: Colors.black54),
            Icon(Icons.calendar_today, size: 30, color: Colors.black54),
            Icon(Icons.manage_accounts, size: 30, color: Colors.black54),
            Icon(Icons.person_outline, size: 30, color: Colors.black54),
          ],
          onTap: (index) {
            setState(() {
              _page = index;
            });
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: signOut,
        tooltip: "Logout",
        child: const Icon(Icons.logout, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // 🔹 MODIFIED: This now calls the new UI widgets and accepts userName
  Widget _buildHomePage(String? currentUserName) { // Accept userName
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(currentUserName), // Pass userName
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 25),
              _buildSectionTitle("Specialist Doctors"),
              const SizedBox(height: 15),
              _buildDoctorList(),
              const SizedBox(height: 25),
              _buildActionGrid(),
              const SizedBox(height: 25),
              _buildEmergencyCallCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 MODIFIED: Header widget to accept and display userName
  Widget _buildHeader(String? currentUserName) { // Accept userName
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome, ${currentUserName ?? 'Patient'} 🎉", // Use passed userName
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1),
          ),
        ),
        const Text(
          "We're thrilled to have you join us",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }

  // 🔹 MODIFIED: Search bar UI updated to match the image
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        readOnly: true,
        onTap: selectDoctorOnMap,
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          hintText: "Search doctor here...",
          border: InputBorder.none,
          suffixIcon: Icon(Icons.filter_list, color: Colors.grey),
        ),
      ),
    );
  }

  // ✅ UNCHANGED: This widget was already good
  Widget _buildSectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          "See All",
          style: TextStyle(
            fontSize: 16,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // 🔹 NEW: Replaced placeholder with a horizontal doctor list
  Widget _buildDoctorList() {
    if (isDoctorsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (doctors.isEmpty) {
      return const Center(child: Text("No doctors available"));
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          return DoctorTile(doc: doctor); // ✅ Reuse DoctorTile here
        },
      ),
    );
  }

  // 🔹 NEW: Replaced "Looking For" with the new action grid
  Widget _buildActionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What are you looking for?",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionCard("Visit a Doctor", "Book now"),
            _buildActionCard("Find a Pharmacy", "Find now"),
            _buildActionCard("Find a Lab", "Find now"),
          ],
        )
      ],
    );
  }

  Widget _buildActionCard(String title, String buttonText) {
    return Expanded(
      child: Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(color: Colors.blue.shade100, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(buttonText, style: const TextStyle(fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }


  // 🔹 NEW: Replaced placeholder emergency card with the new design
  Widget _buildEmergencyCallCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0), // Added padding
      decoration: BoxDecoration( // Added decoration
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.red.shade100, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.call, color: Colors.red.shade700, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Emergency Call",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800),
                ),
                Text(
                  "Contact us for any emergency",
                  style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Add emergency call functionality
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
            ),
            child: const Text("Call Now"),
          )
        ],
      ),
    );
  }
}
class DoctorTile extends StatelessWidget {
  final Map<String, dynamic> doc;
  const DoctorTile({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final clinic = doc['clinic_locations'] as Map<String, dynamic>?;

    final doctorName = doc['profiles']?['name'] ?? "Unknown";
    final specialization = doc['specialization'] ?? "General";
    final clinicName = clinic?['clinic_name'] ?? "N/A";

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder doctor image
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
            ),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Dr. $doctorName",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(specialization,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.blue.shade300, size: 16),
                    Expanded(
                      child: Text(clinicName,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

