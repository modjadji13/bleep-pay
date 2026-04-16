import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// A nearby user detected via BLE
class NearbyUser {
  final String sessionToken; // their BLE broadcast token
  final String deviceName;
  final int rssi; // signal strength - closer = higher

  const NearbyUser({
    required this.sessionToken,
    required this.deviceName,
    required this.rssi,
  });
}

class BleService {
  // Our session token - broadcast so others can find us
  final String sessionToken = const Uuid().v4();
  final List<NearbyUser> nearbyUsers = [];
  Function(List<NearbyUser>)? onNearbyUsersChanged;

  // Start scanning for nearby Bleep Pay users
  Future<void> startScanning() async {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      continuousUpdates: true,
    );

    FlutterBluePlus.scanResults.listen((results) {
      final found = <NearbyUser>[];

      for (final result in results) {
        // Check manufacturer data for our app's identifier
        final data = result.advertisementData.manufacturerData;
        if (data.isNotEmpty) {
          try {
            final raw = data.values.first;
            final decoded = utf8.decode(raw);
            final json = jsonDecode(decoded) as Map<String, dynamic>;

            if (json['app'] == 'bleep_pay') {
              found.add(NearbyUser(
                sessionToken: json['token'] as String,
                deviceName: result.advertisementData.advName.isNotEmpty
                    ? result.advertisementData.advName
                    : 'Nearby User',
                rssi: result.rssi,
              ));
            }
          } catch (_) {
            // Not a Bleep Pay device - ignore
          }
        }
      }

      // Sort by signal strength - closest first
      found.sort((a, b) => b.rssi.compareTo(a.rssi));

      nearbyUsers
        ..clear()
        ..addAll(found);

      onNearbyUsersChanged?.call(nearbyUsers);
    });
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
  }
}

// Provider
class BleNotifier extends StateNotifier<List<NearbyUser>> {
  late final BleService _service;

  BleNotifier() : super([]) {
    _service = BleService();
    _service.onNearbyUsersChanged = (users) => state = users;
    _service.startScanning();
  }

  String get sessionToken => _service.sessionToken;

  @override
  void dispose() {
    _service.stopScanning();
    super.dispose();
  }
}

final bleProvider = StateNotifierProvider<BleNotifier, List<NearbyUser>>(
  (ref) => BleNotifier(),
);
