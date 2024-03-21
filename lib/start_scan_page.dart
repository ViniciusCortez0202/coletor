import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart'; 

class StartScandPage extends StatefulWidget {
  const StartScandPage({super.key});

  @override
  State<StartScandPage> createState() => _StartScandPageState();
}

List<String> _beaconsData = [];

class _StartScandPageState extends State<StartScandPage> {
  final List<String> allowedUUIDs = ["00:FA:B6:1D:DD:EF", "00:FA:B6:1D:DD:E0", "00:FA:B6:1D:DD:FE"];
  List<BluetoothDevice> _systemDevices = [];
  
  List<ScanResult> _scanResults = [];
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  bool _isScanning = false;
  Duration timeToScan = const Duration(seconds: 10);
  late double duration;
  late Timer _timer;

  @override
  void initState() {
    duration = timeToScan.inSeconds.toDouble();
    super.initState();
    _adapterStateStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      /*  if (mounted) {
        setState(() {});
      } */
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      results.forEach((element) {
        if (allowedUUIDs.contains(element.device.id.toString())) {
        _scanResults.add(element);
        }
      });
/*       if (mounted) {
        setState(() {});
      } */
    }, onError: (e) {});

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
/*       if (mounted) {
        setState(() {});
      } */
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  Future<void> startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: timeToScan);
      duration = timeToScan.inSeconds.toDouble();
    } catch (e) {
      print("Erro to start scand");
    }
    if (mounted) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          duration--;
        });
      });
    }
  }

  Future onStopPressed() async {
    try {
      await FlutterBluePlus.systemDevices;
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Stop Scan Error");
    }
  }

  void verifyBluetoothIsOn() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        const SnackBar(content: Text("Por favor, ative o bluetooth"));
      } else {
        startScan();
      }
    });
  }

 Future<void> _saveCSV() async {
  if (_beaconsData.isNotEmpty) {
    try {

      var status = await Permission.storage.status; 

      if (!status.isGranted) { 
        await Permission.storage.request(); 
      } 

      Directory _directory = Directory("/storage/emulated/0/Download"); 

      final exPath = _directory.path; 

      String csvPath = "${exPath}/beacon_data.csv";
      

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



  void showModalTurnOnBluetooth() {}

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
                        verifyBluetoothIsOn();
                      },
                      child: const Text("Scan"),
                    ),
                  if(_scanResults.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        Map<String, Map<String, List<int>>> groupedResults = {};

                        _scanResults.forEach((element) {
                          String coordinates = "${arguments['x']}; ${arguments['y']}";
                          String uuid = element.device.id.toString();
                          int rssiValue = element.rssi;

                          if (groupedResults.containsKey(coordinates)) {
                            if (groupedResults[coordinates]!.containsKey(uuid)) {
                              groupedResults[coordinates]![uuid]!.add(rssiValue);
                            } else {
                              groupedResults[coordinates]![uuid] = [rssiValue];
                            }
                          } else {
                            groupedResults[coordinates] = {uuid: [rssiValue]};
                          }
                        });

                        int maxRssis = groupedResults.values
                            .map((devices) => devices.values.map((rssis) => rssis.length).reduce((a, b) => a > b ? a : b))
                            .reduce((a, b) => a > b ? a : b);

                        groupedResults.forEach((coordinates, devices) {
                          String uuidsString = devices.keys.join(";");
                          print("$coordinates;$uuidsString");

                          for (int i = 0; i < maxRssis; i++) {
                            List<String> rssis = [];

                            devices.forEach((uuid, values) {
                              if (i < values.length) {
                                rssis.add(values[i].toString());
                              } else {
                                rssis.add("-");
                              }
                            });

                            _beaconsData.add("$coordinates;${rssis.join(";")}");
                          }
                          print("ARRAY GLOBAL:");
                          print(_beaconsData);
                        });
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
