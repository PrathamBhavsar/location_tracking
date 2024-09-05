import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:flutter/services.dart'; // Import for MethodChannel

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LocationTrackerScreen(),
    );
  }
}

class LocationTrackerScreen extends StatefulWidget {
  @override
  _LocationTrackerScreenState createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  bool _isTracking = false;
  List<Map<String, dynamic>> _locations = [];
  loc.Location _location = loc.Location();
  loc.LocationData? _currentLocation;
  StreamSubscription<loc.LocationData>? _locationSubscription;
  SharedPreferences? _prefs;
  DateTime? _appOpenedTime;

  static const platform =
      MethodChannel('com.yourcompany.yourapp/foreground_service');

  @override
  void initState() {
    super.initState();
    _loadLocationHistory();
    _appOpenedTime = DateTime.now(); // Initialize with the current time
  }

  void _loadLocationHistory() async {
    _prefs = await SharedPreferences.getInstance();
    List<String>? storedLocations = _prefs?.getStringList('locationHistory');
    if (storedLocations != null) {
      List<Map<String, dynamic>> loadedLocations = [];
      for (String location in storedLocations) {
        var parts = location.split('|');
        if (parts.length == 3) {
          DateTime timestamp = DateTime.parse(parts[0]);
          String locationText = parts[1];
          loadedLocations.add({
            "text": locationText,
            "color":
                timestamp.isBefore(_appOpenedTime!) ? Colors.red : Colors.black,
            "timestamp": timestamp
          });
        }
      }
      setState(() {
        _locations = loadedLocations;
      });
    }
  }

  void _saveLocationHistory() async {
    List<String> storedLocations = _locations
        .map((location) =>
            '${location["timestamp"]}|${location["text"]}|${location["color"] == Colors.red}')
        .toList();

    if (_prefs != null) {
      await _prefs?.setStringList('locationHistory', storedLocations);
    }
  }

  Future<void> _requestPermissions() async {
    perm.PermissionStatus permission =
        await perm.Permission.locationAlways.request();
    if (permission.isDenied) {
      _showPermissionDialog();
    } else if (permission.isPermanentlyDenied) {
      await perm.openAppSettings();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
              'Background location permission is required for location tracking even when the app is in the background. Please enable it in app settings.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await perm.openAppSettings();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startTracking() async {
    try {
      perm.PermissionStatus permission =
          await perm.Permission.locationAlways.status;
      if (permission.isGranted) {
        setState(() {
          _isTracking = true;
        });

        // Start the foreground service
        try {
          final result = await platform.invokeMethod('startService');
          print(result);
        } on PlatformException catch (e) {
          print("Failed to start service: '${e.message}'.");
        }

        _locationSubscription =
            _location.onLocationChanged.listen((loc.LocationData locationData) {
          String formattedTime = DateFormat('HH:mm:ss').format(DateTime.now());
          String newEntry =
              'Lat: ${locationData.latitude}, Long: ${locationData.longitude} at $formattedTime';

          // Print location updates to the console
          print(newEntry);

          setState(() {
            _currentLocation = locationData;
            _locations.insert(0, {
              "text": newEntry,
              "color": Colors
                  .black, // Always black for new entries while app is open
              "timestamp": DateTime.now()
            });
          });

          // Save location history
          _saveLocationHistory();
        });

        await _location.enableBackgroundMode(enable: true);
      } else {
        _requestPermissions();
      }
    } catch (e) {
      print("Error starting location tracking: $e");
    }
  }

  void _stopTracking() async {
    setState(() {
      _isTracking = false;
    });
    _locationSubscription?.cancel();

    // Stop the foreground service
    try {
      final result = await platform.invokeMethod('stopService');
      print(result);
    } on PlatformException catch (e) {
      print("Failed to stop service: '${e.message}'.");
    }

    await _location.enableBackgroundMode(enable: false);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sort locations in descending order based on the timestamp
    _locations.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

    return Scaffold(
      appBar: AppBar(
        title: Text('Background Location Tracker'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              if (_isTracking) {
                _stopTracking();
              } else {
                _startTracking();
              }
            },
            child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _locations[index]["text"],
                    style: TextStyle(color: _locations[index]["color"]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
