import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _initialPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Pick Clinic Location")),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 15,
              ),
              myLocationEnabled: true,
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
                )
              },
            ),
          ),
          if (_pickedAddress != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "📍 $_pickedAddress",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_pickedLocation != null) {
            Navigator.pop(context, {
              "lat": _pickedLocation!.latitude,
              "lng": _pickedLocation!.longitude,
              "address": _pickedAddress ?? "",
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please tap on the map to pick a location")),
            );
          }
        },
        label: const Text("Confirm Location"),
        icon: const Icon(Icons.check),
      ),
    );
  }
}