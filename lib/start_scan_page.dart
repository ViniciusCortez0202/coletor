import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class StartScandPage extends StatefulWidget {
  const StartScandPage({super.key});

  @override
  State<StartScandPage> createState() => _StartScandPageState();
}

class _StartScandPageState extends State<StartScandPage> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  bool _isScanning = false;
  Duration timeToScan = const Duration(seconds: 15);
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
      _scanResults.addAll(results);
      results.forEach((element) {
        print("${element.device.remoteId}; ${element.rssi}");
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
                        verifyBluetoothIsOn();
                      },
                      child: const Text("Scan"),
                    ),
                  if(_scanResults.isNotEmpty)
                    ElevatedButton(
                        onPressed: () {
                          _scanResults.forEach((element) {                            
                            print("(${arguments['x']}; ${arguments['y']}) - ${element.device.remoteId} - ${element.rssi}");
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
