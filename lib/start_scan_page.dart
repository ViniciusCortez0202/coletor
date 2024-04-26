import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:geolocator/geolocator.dart';
import 'package:open_settings/open_settings.dart';
import 'package:coletor/permission_services.dart';
import 'package:coletor/controller.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_kalman/simple_kalman.dart';

class StartScandPage extends StatefulWidget {
  const StartScandPage({super.key});

  @override
  State<StartScandPage> createState() => _StartScandPageState();
}

List<String> _beaconsData = [];

class _StartScandPageState extends State<StartScandPage> {
  final List<String> allowedUUIDs = ["00:FA:B6:1D:DE:07", "00:FA:B6:1D:DD:F8", "00:FA:B6:12:E8:86"];
  
  List<String> _scanResults = [];
  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;
  bool _isScanning = false;
  Duration timeToScan = const Duration(seconds: 120);
  late double duration;
  late Timer _timer;
  final kalman = SimpleKalman(errorMeasure: 1, errorEstimate: 150, q: 0.3);

  @override
  void initState() {
    duration = timeToScan.inSeconds.toDouble();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  initScanBeacon() async {
    final regions = <Region>[];

    regions.add(
        Region(identifier: 'com.beacon', proximityUUID: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E"));

    _streamRanging = flutterBeacon.ranging(regions).listen((RangingResult result) {
      if (result != null && result.beacons.isNotEmpty) {
        _isScanning = true;
        debugPrint('Found beacons: ${result.beacons.length}');
        List<int> rssis = result.beacons.map((beacon) => beacon.rssi).toList();

        List<double> filteredRssis = rssis.map((rssi) => kalman.filtered(rssi.toDouble())).toList();

        List<int> filteredRssisInt = filteredRssis.map((value) => value.toInt()).toList();

        debugPrint('RSSIs: $rssis');
        _scanResults.add(filteredRssisInt.join(';'));
    } else {
      debugPrint('No beacons found');
    }
    });
  }

  Future<void> startScan() async {
    print('Listening to bluetooth state');
    await flutterBeacon.initializeAndCheckScanning;
    _streamBluetooth = flutterBeacon.bluetoothStateChanged().listen((BluetoothState state) async {
      print('Bluetooth State: $state');
      if (state == BluetoothState.stateOn) {
        Timer(Duration(seconds: 120), () {
          _streamRanging?.cancel();
          _streamBluetooth?.cancel();
          _timer.cancel();
          setState(() {
            _isScanning = false;
          });
        });
        initScanBeacon();
      } else {
        _streamRanging?.pause();
      }
    });

    if (mounted) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          duration--;
        });
      });
    }
  }

 Future<void> _saveCSV() async {
  if (_beaconsData.isNotEmpty) {
    try {

      var status = await Permission.storage.status; 
      print("STATUS: $status");
      if (!status.isGranted) { 
        await Permission.storage.request(); 
      } 

      Directory _directory = Directory("/storage/emulated/0/Download"); 

      final exPath = _directory.path; 

      String csvPath = "${exPath}/beacon_data_k.csv";
      

      File csvFile = File(csvPath);

      List<List<dynamic>> csvData = _beaconsData.map((row) => row.split(';')).toList();
      
      String csvContent = const ListToCsvConverter().convert(csvData);
      
      await csvFile.writeAsString(csvContent);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Arquivo CSV salvo em ${csvFile.path}")),
      );
    } catch (e) {
      print("Erro ao salvar o arquivo CSV: $e");
    }
  } else {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Nenhum dado disponível para exportar")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final arguments = (ModalRoute.of(context)?.settings.arguments ??
        <String, dynamic>{}) as Map;

    int minute = 0;
    int seconds = 0;

    if (duration != 0) {
      minute = (60 % duration) ~/ 60;
      seconds = (duration - (minute * 60)).toInt();
    } else {
      _timer.cancel();
    }

    return Scaffold(
      appBar: AppBar(),
      body: Container(
        child: Center(
          child: _isScanning
              ? Column(
                  children: [
                    Text('$minute:$seconds'),
                    TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1),
                        duration: timeToScan,
                        builder: (context, value, _) {
                          return CircularProgressIndicator(value: value);
                        }),
                    const SizedBox(height: 20),
                    Text(
                        "Estamos escaneando para (${arguments['x']}; ${arguments['y']})"),
                  ],
                )
              : Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _saveCSV();
                    },
                    child: Text("Exportar CSV"),
                  ),
                  ElevatedButton(
                      onPressed: () {
                        startScan();
                      },
                      child: const Text("Scan"),
                    ),
                  if(_scanResults.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        _scanResults.forEach((element) {
                          String coordinates = "${arguments['x']}; ${arguments['y']}";
                            print("ação salvar dados;");
                            print(coordinates);
                            print(element);
                            _beaconsData.add("$coordinates;${element}");
                          });
                          print("ARRAY GLOBAL:");
                          print(_beaconsData);
                      },
                        child: const Text("Salvar dados"),
                      ),
                ],
              ),
        ),
      ),
    );
  }
}
