import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _pickedLocation;
  String? _pickedAddress;
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(19.0760, 72.8777); // fallback
  bool _isLoading = true;
  BitmapDescriptor? _customMarkerIcon;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    // Load custom marker and determine user's position
    await _loadCustomMarker();
    await _determinePosition();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await _resizeAndCreateBitmap(
          'assets/icon/doctor_marker.png', 100, 100);
      if (mounted) {
        setState(() {
          _customMarkerIcon = icon;
        });
      }
    } catch (e) {
      debugPrint('Error loading custom marker: $e');
    }
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

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _initialPosition = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
      }
    } catch (e) {
      debugPrint("Error getting current position: $e");
    }
  }

  Future<void> _getAddressFromLatLng(LatLng pos) async {
    try {
      List<Placemark> placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _pickedAddress =
          "${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
        });
      }
    } catch (e) {
      debugPrint("Error in geocoding: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Pick Clinic Location",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (LatLng position) async {
              setState(() {
                _pickedLocation = position;
              });
              await _getAddressFromLatLng(position);
            },
            markers: _pickedLocation == null
                ? {}
                : {
              Marker(
                markerId: const MarkerId("picked-location"),
                position: _pickedLocation!,
                icon: _customMarkerIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
              ),
            },
          ),
          if (_pickedAddress != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 80, // stays above FAB
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pickedAddress!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () {
          if (_pickedLocation != null) {
            Navigator.pop(context, {
              "lat": _pickedLocation!.latitude,
              "lng": _pickedLocation!.longitude,
              "address": _pickedAddress ?? "",
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("⚠️ Please tap on the map to pick a location")),
            );
          }
        },
        label: const Text("Confirm Location",
            style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}