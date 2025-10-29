import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/patient/doctor_details.dart';
import 'package:shimmer/shimmer.dart';

// -----------------------------------------------------------------------------
// Doctor List Page (Refactored)
// -----------------------------------------------------------------------------

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({super.key});

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  // --- UI Colors from ProfilesScreen Theme ---
  static const Color primaryColor = Color(0xFF00AEEF);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  // --- End Theme Colors ---

  // --- Updated Text Styles to use Theme Colors ---
  final TextStyle _kDoctorNameStyle =
  TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor);
  final TextStyle _kDoctorSpecialtyStyle =
  TextStyle(fontSize: 14, color: lightTextColor);
  final TextStyle _kDoctorQualificationStyle =
  TextStyle(fontSize: 13, color: lightTextColor);

  List<Map<String, dynamic>> doctors = [];
  final Set<int> _favoritedIndices = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDoctors();
  }

  Future<void> fetchDoctors() async {
    setState(() => isLoading = true);
    try {
      final response = await AuthService().getApprovedDoctors();
      if (mounted) {
        setState(() {
          doctors = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // --- AppBar from ProfilesScreen flow ---
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.medical_services_outlined, // Icon for doctors
                color: primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Your Doctor',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Book appointments with specialists',
                    style: TextStyle(
                      color: lightTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // No "Add" button needed here
          ],
        ),
      ),
      // --- Body structure from ProfilesScreen flow ---
      body: isLoading
          ? _buildShimmerList()
          : doctors.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: fetchDoctors,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            final heroTag = "doctorImage_$index";
            final bool isFavorited =
            _favoritedIndices.contains(index);

            return _DoctorCard(
              doctor: doctor,
              heroTag: heroTag,
              isFavorited: isFavorited,
              onFavoritePressed: () {
                setState(() {
                  if (isFavorited) {
                    _favoritedIndices.remove(index);
                  } else {
                    _favoritedIndices.add(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to favorites!'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                });
              },
              onBookPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DoctorDetailsPage(doctor: doctor),
                  ),
                );
              },
              // Pass styles
              doctorNameStyle: _kDoctorNameStyle,
              doctorSpecialtyStyle: _kDoctorSpecialtyStyle,
              doctorQualificationStyle: _kDoctorQualificationStyle,
              primaryColor: primaryColor,
            );
          },
        ),
      ),
    );
  }

  /// Shimmer list matching the Doctor Card layout
  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const _ShimmerDoctorCard(),
    );
  }

  /// Empty state widget from ProfilesScreen flow
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Doctors Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Approved doctors will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Doctor Card
// -----------------------------------------------------------------------------
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final String heroTag;
  final bool isFavorited;
  final VoidCallback onFavoritePressed;
  final VoidCallback onBookPressed;
  // Styles passed from parent
  final TextStyle doctorNameStyle;
  final TextStyle doctorSpecialtyStyle;
  final TextStyle doctorQualificationStyle;
  final Color primaryColor;

  const _DoctorCard({
    required this.doctor,
    required this.heroTag,
    required this.isFavorited,
    required this.onFavoritePressed,
    required this.onBookPressed,
    required this.doctorNameStyle,
    required this.doctorSpecialtyStyle,
    required this.doctorQualificationStyle,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Use margin from reference
      padding: const EdgeInsets.all(16), // Use padding from reference
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Use radius from reference
        border: Border.all(color: Colors.grey.shade200), // Use border
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: heroTag,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[200],
              backgroundImage: doctor["image_url"] != null &&
                  doctor["image_url"].isNotEmpty
                  ? NetworkImage(
                doctor["image_url"],
              )
                  : null,
              child: doctor["image_url"] == null
                  ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor["profiles"]["name"] ?? "", style: doctorNameStyle),
                const SizedBox(height: 4),
                Text("Consultant, ${doctor["specialization"] ?? ""}",
                    style: doctorSpecialtyStyle),
                const SizedBox(height: 2),
                Text("Experience: ${doctor["years_of_experience"] ?? 0} years",
                    style: doctorQualificationStyle),
                const SizedBox(height: 8),
                SizedBox(
                  height: 35,
                  child: ElevatedButton(
                    onPressed: onBookPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, // Use theme color
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text("Appointment Now"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: isFavorited ? Colors.red : Colors.grey,
              size: 24,
            ),
            onPressed: onFavoritePressed,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Shimmer Card
// -----------------------------------------------------------------------------
class _ShimmerDoctorCard extends StatelessWidget {
  const _ShimmerDoctorCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
            ),
            const SizedBox(width: 12),
            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 17, width: 150, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 14, width: 200, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(height: 13, width: 100, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(
                      height: 35,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Favorite icon
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}