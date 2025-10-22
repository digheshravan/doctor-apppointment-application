import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/patient/doctor_details.dart';
import 'package:shimmer/shimmer.dart';

const TextStyle _kDoctorNameStyle =
TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87);
const TextStyle _kDoctorSpecialtyStyle =
TextStyle(fontSize: 14, color: Colors.black54);
const TextStyle _kDoctorQualificationStyle =
TextStyle(fontSize: 13, color: Colors.black54);

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({super.key});

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
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

      setState(() {
        doctors = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
              child: Text(
                "Doctor List",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: fetchDoctors,
                color: const Color(0xFF2D8CFF),
                child: isLoading
                    ? _buildShimmerList()
                    : doctors.isEmpty
                    ? const Center(child: Text("No doctors found"))
                    : ListView.builder(
                  padding: EdgeInsets.only(
                    top: 0,
                    bottom:
                    MediaQuery.of(context).padding.bottom + 110,
                  ),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final heroTag = "doctorImage_$index";
                    final bool isFavorited =
                    _favoritedIndices.contains(index);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: heroTag,
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: doctor["image_url"] !=
                                  null &&
                                  doctor["image_url"].isNotEmpty
                                  ? NetworkImage(
                                doctor["image_url"],
                              )
                                  : null,
                              child: doctor["image_url"] == null
                                  ? Icon(Icons.person,
                                  size: 40,
                                  color: Colors.grey[600])
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                    doctor["profiles"]["name"] ?? "",
                                    style: _kDoctorNameStyle),
                                const SizedBox(height: 4),
                                Text(
                                    "Consultant, ${doctor["specialization"] ?? ""}",
                                    style: _kDoctorSpecialtyStyle),
                                const SizedBox(height: 2),
                                Text(
                                    "Experience: ${doctor["years_of_experience"] ?? 0} years",
                                    style: _kDoctorQualificationStyle),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 35,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DoctorDetailsPage(
                                                  doctor: doctor),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      const Color(0xFF2D8CFF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 16),
                                    ),
                                    child: const Text(
                                        "Appointment Now"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorited
                                  ? Colors.red
                                  : Colors.grey,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isFavorited) {
                                  _favoritedIndices.remove(index);
                                } else {
                                  _favoritedIndices.add(index);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                      Text('Added to favorites!'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 120,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
