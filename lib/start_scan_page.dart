import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:simple_kalman/simple_kalman.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

import 'dart:convert'; // Importação necessária para jsonEncode
import 'package:http/http.dart' as http;

class StartScandPage extends StatefulWidget {
  const StartScandPage({super.key});

  @override
  State<StartScandPage> createState() => _StartScandPageState();
}

List<String> _beaconsData = [];

class _StartScandPageState extends State<StartScandPage> {
  List<String> _scanResults = [];
  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;
  bool _isScanning = false;
  int time_seconds = 60;
  Duration timeToScan = const Duration(seconds: 60);
  late double duration;
  late Timer _timer;
  final kalman = SimpleKalman(errorMeasure: 1, errorEstimate: 150, q: 0.3);
  static const platform = MethodChannel('samples.flutter.dev/beacons');

  // Lista de valores do sensor magnético
  List<MagnetometerEvent> _magnetometerValues = [];
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;

  @override
  void initState() {
    duration = timeToScan.inSeconds.toDouble();

    _magnetometerSubscription = magnetometerEvents.listen((event) {
      setState(() {
        _magnetometerValues = [event];
        _magnetometerValues.add(event);
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _magnetometerSubscription.cancel();
    super.dispose();
  }

  Future<void> startScan() async {
    print('Listening to bluetooth state');
    await flutterBeacon.initializeAndCheckScanning;
    _streamBluetooth = flutterBeacon.bluetoothStateChanged().listen((BluetoothState state) async {
      print('Bluetooth State: $state');
      if (state == BluetoothState.stateOn) {
        Timer(Duration(seconds: time_seconds), () {
          _streamRanging?.cancel();
          _streamBluetooth?.cancel();
          _timer.cancel();
          setState(() {
            _isScanning = false;
          });
        });
        startRead();
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

  Future<void> postData(List<String> data) async {
    final response = await http.post(
        Uri.parse('https://rei-dos-livros-api-f270d083e2b1.herokuapp.com/knn_position'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': data}),
      );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final int itemsInserted = responseData['total'] ?? 0;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Dados Inseridos"),
            content: Text("Foi inserido $itemsInserted itens"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    } else {
      print("Erro ao enviar os dados: ${response.statusCode}");
    }
  }

  startRead() async {
    try {
      _isScanning = true;
      await platform.invokeMethod<String>('startListener');
      Future.delayed(Duration(seconds: time_seconds), () async {
        await stopRead();
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  stopRead() async {
    try {
      final result = await platform.invokeMethod<List<dynamic>>('stopListener');

      if (result != null) {
        for (var i = 0; i < result.length; i++) {
          List<dynamic> dynamicList = result[i];
          List<int> valuesListAsInt = dynamicList.map((e) => e as int).toList();

          double magneticX = _magnetometerValues.last.x;
          double magneticY = _magnetometerValues.last.y;
          double magneticZ = _magnetometerValues.last.z;
          double magneticRssi = sqrt(pow(magneticX, 2) + pow(magneticY, 2) + pow(magneticZ, 2));

          // Cria uma lista com os valores magnéticos convertidos para int
          List<int> magneticData = [magneticX.toInt(), magneticY.toInt(), magneticZ.toInt(), magneticRssi.toInt()];

          // Combina a lista de valores com os dados magnéticos
          List<int> bleWithMagnetic = valuesListAsInt + magneticData;

          _scanResults.add(bleWithMagnetic.join(';'));
        }
      }

      _isScanning = false;
    } on PlatformException catch (e) {
      print(e);
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
        String csvPath = "${exPath}/beacon_datav2.csv";
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
    final arguments = (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{}) as Map;

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
                    Text("Estamos escaneando para (${arguments['x']}; ${arguments['y']})"),
                  ],
                )
              : Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Tempo de escaneamento (segundos)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          time_seconds = int.tryParse(value) ?? 60;
                          timeToScan = Duration(seconds: time_seconds);
                          duration = timeToScan.inSeconds.toDouble();
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        //_saveCSV();
                        postData(_beaconsData);
                      },
                      child: Text("Exportar CSV"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        startScan();
                      },
                      child: const Text("Scan"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _scanResults.forEach((element) {
                          String coordinates = "${arguments['x']}; ${arguments['y']}";
                          _beaconsData.add("$coordinates;${element}");
                        });

                        _scanResults.clear();
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
