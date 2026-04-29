import 'package:flutter/services.dart';

import '../data/local/database_helper.dart';

class NmeaBridgeDevice {
  final String? name;
  final String address;

  const NmeaBridgeDevice({
    required this.address,
    this.name,
  });

  factory NmeaBridgeDevice.fromMap(Map<dynamic, dynamic> map) {
    return NmeaBridgeDevice(
      name: map['name']?.toString(),
      address: map['address']?.toString() ?? '',
    );
  }

  String get label {
    final displayName = name?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return '$displayName ($address)';
    }
    return address;
  }

  bool get looksLikeGnssReceiver {
    final value = '${name ?? ''} $address'.toLowerCase();
    return value.contains('gnss') ||
        value.contains('tersus') ||
        value.contains('oscar') ||
        value.contains('nmea');
  }
}

class NmeaBridgeStatus {
  final String status;
  final bool mockLocationSelected;
  final String? lastNmea;
  final Map<String, dynamic>? lastLocation;
  final String? bluetoothName;
  final String? bluetoothAddress;

  const NmeaBridgeStatus({
    required this.status,
    required this.mockLocationSelected,
    this.lastNmea,
    this.lastLocation,
    this.bluetoothName,
    this.bluetoothAddress,
  });

  factory NmeaBridgeStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawLocation = map['lastLocation'];
    return NmeaBridgeStatus(
      status: map['status']?.toString() ?? 'unknown',
      mockLocationSelected: map['mockLocationSelected'] == true,
      lastNmea: map['lastNmea']?.toString(),
      lastLocation: rawLocation is Map
          ? rawLocation.map((key, value) => MapEntry(key.toString(), value))
          : null,
      bluetoothName: map['bluetoothName']?.toString(),
      bluetoothAddress: map['bluetoothAddress']?.toString(),
    );
  }
}

class NmeaBridgeService {
  static const MethodChannel _channel =
      MethodChannel('com.srm.collecte/nmea_bridge');
  static const String _preferredAddressKey =
      'nmea_bridge_preferred_bluetooth_address';
  static const String _preferredNameKey =
      'nmea_bridge_preferred_bluetooth_name';

  Future<bool> isMockLocationSelected() async {
    return await _channel.invokeMethod<bool>('isMockLocationSelected') ?? false;
  }

  Future<void> openMockLocationSettings() async {
    await _channel.invokeMethod<void>('openMockLocationSettings');
  }

  Future<void> openBluetoothSettings() async {
    await _channel.invokeMethod<void>('openBluetoothSettings');
  }

  Future<bool> startMockProvider() async {
    return await _channel.invokeMethod<bool>('startMockProvider') ?? false;
  }

  Future<void> stopMockProvider() async {
    await _channel.invokeMethod<void>('stopMockProvider');
  }

  Future<Map<String, dynamic>> pushLocation({
    required double latitude,
    required double longitude,
    double? altitude,
    double accuracy = 1.0,
    double? speed,
    double? bearing,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pushLocation',
      {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'speed': speed,
        'bearing': bearing,
      },
    );
    return result?.map((key, value) => MapEntry(key.toString(), value)) ??
        const {};
  }

  Future<Map<String, dynamic>> pushNmea(String sentence) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pushNmea',
      {'sentence': sentence},
    );
    return result?.map((key, value) => MapEntry(key.toString(), value)) ??
        const {};
  }

  Future<List<NmeaBridgeDevice>> listBondedBluetoothDevices() async {
    final result = await _channel.invokeMethod<List<dynamic>>(
          'listBondedBluetoothDevices',
        ) ??
        const [];
    return result
        .whereType<Map<dynamic, dynamic>>()
        .map(NmeaBridgeDevice.fromMap)
        .where((device) => device.address.isNotEmpty)
        .toList();
  }

  Future<void> savePreferredBluetoothDevice(NmeaBridgeDevice device) async {
    await DatabaseHelper().saveAppMetadataValue(
      _preferredAddressKey,
      device.address,
      eventType: 'SET_NMEA_BRIDGE_DEVICE',
      payload: {'address': device.address, 'name': device.name},
    );
    final name = device.name?.trim();
    if (name != null && name.isNotEmpty) {
      await DatabaseHelper().saveAppMetadataValue(
        _preferredNameKey,
        name,
      );
    }
  }

  Future<NmeaBridgeDevice?> getPreferredBluetoothDevice() async {
    final address =
        await DatabaseHelper().getAppMetadataValue(_preferredAddressKey);
    if (address == null || address.trim().isEmpty) return null;
    final name = await DatabaseHelper().getAppMetadataValue(_preferredNameKey);
    return NmeaBridgeDevice(address: address.trim(), name: name);
  }

  Future<void> clearPreferredBluetoothDevice() async {
    await DatabaseHelper().deleteAppMetadataValue(
      _preferredAddressKey,
      eventType: 'CLEAR_NMEA_BRIDGE_DEVICE',
    );
    await DatabaseHelper().deleteAppMetadataValue(_preferredNameKey);
  }

  Future<NmeaBridgeDevice?> resolveAutoConnectDevice() async {
    final devices = await listBondedBluetoothDevices();
    if (devices.isEmpty) return null;

    final preferred = await getPreferredBluetoothDevice();
    if (preferred != null) {
      for (final device in devices) {
        if (device.address == preferred.address) {
          return device;
        }
      }
      return preferred;
    }

    final gnssCandidates =
        devices.where((device) => device.looksLikeGnssReceiver).toList();
    if (gnssCandidates.length == 1) {
      await savePreferredBluetoothDevice(gnssCandidates.first);
      return gnssCandidates.first;
    }

    return null;
  }

  Future<NmeaBridgeStatus> connectBluetooth(String address) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'connectBluetooth',
      {'address': address},
    );
    return NmeaBridgeStatus.fromMap(result ?? const {});
  }

  Future<NmeaBridgeStatus> disconnectBluetooth() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'disconnectBluetooth',
    );
    return NmeaBridgeStatus.fromMap(result ?? const {});
  }

  Future<NmeaBridgeStatus> getStatus() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getStatus',
    );
    return NmeaBridgeStatus.fromMap(result ?? const {});
  }
}
