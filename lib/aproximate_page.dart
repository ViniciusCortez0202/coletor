import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:simple_kalman/simple_kalman.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AproximatePage extends StatefulWidget {
  @override
  _AproximatePageState createState() => _AproximatePageState();
}

class _AproximatePageState extends State<AproximatePage> {
  static const platform = MethodChannel('samples.flutter.dev/beacons');
  static const eventChannel = EventChannel('bluetoothBleEvent');
  bool _isMounted = false;
  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    listeningState();
  }

  
  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
    _streamRanging?.cancel();
    _streamBluetooth?.cancel();
  }

  // Mock de dados dos beacons com UUID, nome da obra e distância
  List<Map<String, dynamic>> beaconsProximos = [];

  double calculateDistance(int rssi, {int rssiRef = -84, double n = 2.0}) {
    double distance = (pow(10, (rssiRef - rssi) / (10 * n))) as double;
    return double.parse(distance.toStringAsFixed(2));
  }

  void listeningState() async {
    print('Listening to bluetooth state');
    await flutterBeacon.initializeAndCheckScanning;
    _streamBluetooth = flutterBeacon
        .bluetoothStateChanged()
        .listen((BluetoothState state) async {
      print('Bluetooth State: $state');
      if (state == BluetoothState.stateOn) {
        startRead();
      } else {
        _streamRanging!.pause();
      }
    });
  }

  void loadEvent() {
    try {
      if (!_isMounted) return;
      eventChannel.receiveBroadcastStream().forEach((event) {
        if (event != null) {
          List<dynamic> beaconsList = event as List<dynamic>;
          List<Map<String, dynamic>> updatedProximos = [];
          for (var beaconData in beaconsList) {
            String uuid = beaconData['uuid'];
            int rssi = beaconData['rssi'] is int ? beaconData['rssi'] : 0;
            double distance = calculateDistance(rssi);

            if (distance <= 1.0) {
              updatedProximos.add({'uuid': uuid, 'distancia': distance});
            }
          }

          setState((){
            beaconsProximos = updatedProximos;
          });
        }
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  startRead() async {
    try {
      await platform.invokeMethod<String>('startListener');
      loadEvent();
    } on PlatformException catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Aproximação obras'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            Text(
              "Beacons Próximos (<= 2m):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...beaconsProximos.map((beacon) {
              String uuid = beacon['uuid'] ?? "UUID desconhecido";
              String distancia =
                  (beacon['distancia'] ?? "Desconhecida").toString();

              return ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Você selecionou o beacon: $uuid')),
                  );
                },
                child: Text("UUID: $uuid - Distância: $distancia metros"),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
