import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class DoctorClinicsMapPage extends StatefulWidget {
  final List<Map<String, dynamic>> clinics;

  const DoctorClinicsMapPage({super.key, required this.clinics});

  @override
  State<DoctorClinicsMapPage> createState() => _DoctorClinicsMapPageState();
}

class _DoctorClinicsMapPageState extends State<DoctorClinicsMapPage> {
  Set<Marker> markers = {};
  BitmapDescriptor? customIcon;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  /// Resize and load custom marker
  Future<BitmapDescriptor> _resizeAndLoadMarker(
      String assetPath, int width, int height) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
      targetHeight: height,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData =
    await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadCustomMarker() async {
    try {
      customIcon = await _resizeAndLoadMarker(
        'assets/icon/doctor_marker.png',
        110, // width
        110, // height
      );
      _setMarkers();
    } catch (e) {
      debugPrint('Error loading custom marker: $e');
      customIcon = BitmapDescriptor.defaultMarker;
      _setMarkers();
    }
  }

  void _setMarkers() {
    final tempMarkers = widget.clinics.map((clinic) {
      final lat = double.tryParse(clinic["latitude"].toString()) ?? 0;
      final lng = double.tryParse(clinic["longitude"].toString()) ?? 0;

      return Marker(
        markerId: MarkerId(clinic["clinic_id"].toString()),
        position: LatLng(lat, lng),
        icon: customIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: clinic["clinic_name"] ?? "Clinic",
          snippet: clinic["address"] ?? "",
        ),
        onTap: () {
          _openNavigation(lat, lng);
        },
      );
    }).toSet();

    setState(() => markers = tempMarkers);
  }

  void _openNavigation(double lat, double lng) async {
    final url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open maps")),
      );
    }
  }

  /// Move camera to fit all clinics + current location
  Future<void> _goToFitAllLocations() async {
    try {
      // Get user location
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Prepare all LatLngs (clinics + current location)
      List<LatLng> allPoints = widget.clinics.map((clinic) {
        final lat = double.tryParse(clinic['latitude'].toString()) ?? 0;
        final lng = double.tryParse(clinic['longitude'].toString()) ?? 0;
        return LatLng(lat, lng);
      }).toList();

      allPoints.add(LatLng(position.latitude, position.longitude));

      // Compute LatLngBounds
      double south = allPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
      double north = allPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      double west = allPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
      double east = allPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

      final bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      // Move camera to fit all points with padding
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80), // 80px padding
      );
    } catch (e) {
      debugPrint('Error moving camera to fit all locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng initialPosition = const LatLng(19.0760, 72.8777); // default Mumbai

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Clinics"),
        backgroundColor: const Color(0xFF2D8CFF),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialPosition,
          zoom: 12,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) async {
          _mapController = controller;
          await _goToFitAllLocations(); // Move camera to include all points
        },
      ),
    );
  }
}