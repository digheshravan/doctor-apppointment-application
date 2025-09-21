import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DoctorMapPage extends StatefulWidget {
  const DoctorMapPage({super.key});

  @override
  State<DoctorMapPage> createState() => _DoctorMapPageState();
}

class _DoctorMapPageState extends State<DoctorMapPage> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  BitmapDescriptor? _doctorIcon;

  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _filteredClinics = [];
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadDoctorIcon(resizeWidth: 100, resizeHeight: 100);
    await _fetchClinics();
  }

  Future<BitmapDescriptor> _resizeAndCreateBitmap(
      String assetPath, int width, int height) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
      targetHeight: height,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? bytes =
    await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _loadDoctorIcon({int resizeWidth = 80, int resizeHeight = 80}) async {
    try {
      final icon = await _resizeAndCreateBitmap(
          'assets/icon/doctor_marker.png', resizeWidth, resizeHeight);
      setState(() => _doctorIcon = icon);
      if (_clinics.isNotEmpty) _applyMarkers();
    } catch (e) {
      debugPrint('Error loading custom marker: $e');
    }
  }

  Future<void> _fetchClinics() async {
    try {
      final response = await supabase.from('clinic_locations').select('''
      clinic_id,
      clinic_name,
      address,
      latitude,
      longitude,
      doctors (
        doctor_id,
        specialization,
        profiles (
          name
        )
      )
    ''').order('clinic_name', ascending: true);

      debugPrint("Fetched clinics: ${response.toString()}"); // 👈 ADD THIS

      final List<Map<String, dynamic>> fetched =
      List<Map<String, dynamic>>.from(response ?? []);

      setState(() {
        _clinics = fetched;
        _filteredClinics = List<Map<String, dynamic>>.from(_clinics);
      });

      _applyMarkers();

      // Safely move to first clinic location
      if (_clinics.isNotEmpty && _mapController != null) {
        final first = _clinics.first;
        final lat = _toDouble(first['latitude']);
        final lng = _toDouble(first['longitude']);
        if (lat != null && lng != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching clinics: $e');
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _extractDoctorName(Map<String, dynamic> clinic) {
    try {
      final doctorsNode = clinic['doctors'];
      if (doctorsNode == null) return 'Unknown';

      if (doctorsNode is List && doctorsNode.isNotEmpty) {
        final profiles = doctorsNode.first['profiles'];
        if (profiles is Map && profiles['name'] != null) {
          return profiles['name'].toString();
        }
      } else if (doctorsNode is Map) {
        final profiles = doctorsNode['profiles'];
        if (profiles is Map && profiles['name'] != null) {
          return profiles['name'].toString();
        }
      }
    } catch (_) {}
    return 'Unknown';
  }

  String _extractDoctorSpecialization(Map<String, dynamic> clinic) {
    try {
      final doctorsNode = clinic['doctors'];
      if (doctorsNode == null) return 'N/A';
      if (doctorsNode is List && doctorsNode.isNotEmpty) {
        return doctorsNode.first['specialization']?.toString() ?? 'N/A';
      } else if (doctorsNode is Map) {
        return doctorsNode['specialization']?.toString() ?? 'N/A';
      }
    } catch (_) {}
    return 'N/A';
  }

  void _applyMarkers() {
    final Set<Marker> markers = {};
    for (final clinic in _filteredClinics) {
      final lat = _toDouble(clinic['latitude']);
      final lng = _toDouble(clinic['longitude']);
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(clinic['clinic_id'].toString()),
          position: LatLng(lat, lng),
          icon: _doctorIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: clinic['clinic_name'] ?? 'Clinic',
            snippet:
            '${_extractDoctorName(clinic)} • ${clinic['address'] ?? ''}',
          ),
          onTap: () => _showClinicBottomSheet(clinic),
        ),
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  void _filterClinics(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredClinics = List<Map<String, dynamic>>.from(_clinics);
      _applyMarkers();
      return;
    }

    final results = _clinics.where((clinic) {
      final clinicName = (clinic['clinic_name'] ?? '').toString().toLowerCase();
      final address = (clinic['address'] ?? '').toString().toLowerCase();
      final doctorName = _extractDoctorName(clinic).toLowerCase();
      return clinicName.contains(q) || address.contains(q) || doctorName.contains(q);
    }).toList();

    setState(() {
      _filteredClinics = results;
    });
    _applyMarkers();

    if (_filteredClinics.isNotEmpty && _mapController != null) {
      final fc = _filteredClinics.first;
      final lat = _toDouble(fc['latitude']);
      final lng = _toDouble(fc['longitude']);
      if (lat != null && lng != null) {
        _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13));
      }
    }
  }

  void _showClinicBottomSheet(Map<String, dynamic> clinic) {
    final doctorName = _extractDoctorName(clinic);
    final specialization = _extractDoctorSpecialization(clinic);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF2193b0),
                child: Icon(Icons.local_hospital, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(clinic['clinic_name'] ?? 'Unnamed Clinic',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 4),
                  Text('Dr. $doctorName ($specialization)', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                ]),
              )
            ]),
            const SizedBox(height: 12),
            Text('Address: ${clinic['address'] ?? 'Not available'}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF2193b0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final doctor = clinic['doctors']; // doctors is a Map

                    if (doctor != null) {
                      final doctorId = doctor['doctor_id'];
                      final doctorName = doctor['profiles'] != null
                          ? doctor['profiles']['name']
                          : "Unknown Doctor";
                      final specialization = doctor['specialization'] ?? "General";

                      // Return doctor info back to BookAppointmentPage
                      Navigator.pop(context); // close bottom sheet
                      Navigator.pop(context, {
                        'doctorId': doctorId,
                        'doctorName': doctorName,
                        'clinicName': clinic['clinic_name'],
                        'address': clinic['address'],
                        'specialization': specialization,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No doctor available for this clinic")),
                      );
                    }
                  },
                  child: const Text(
                    'Book Appointment',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                )
            ),
          ]),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Clinics'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(19.0760, 72.8777), zoom: 12),
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
            if (_clinics.isNotEmpty) {
              final first = _clinics.first;
              final lat = _toDouble(first['latitude']);
              final lng = _toDouble(first['longitude']);
              if (lat != null && lng != null) {
                _mapController!.moveCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13));
              }
            }
          },
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchController,
              onChanged: _filterClinics,
              decoration: InputDecoration(
                hintText: 'Search clinic, address or doctor...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterClinics('');
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}