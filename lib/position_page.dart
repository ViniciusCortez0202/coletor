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

class PositionPage extends StatefulWidget {
  const PositionPage({Key? key}) : super(key: key);

  @override
  _PositionPageState createState() => _PositionPageState();
}

class _PositionPageState extends State<PositionPage> {
  int currentX = 0;
  int currentY = 0;

  int realX = 0;
  int realY = 0;

  bool _isMounted = false;
  int time_seconds = 6;
  Map<String, dynamic> fetchedData = {};

  List<int?> lastRssis = [];
  String? description;

  static const platform = MethodChannel('samples.flutter.dev/beacons');
  static const eventChannel = EventChannel('bluetoothBleEvent');

  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;
  final kalman = SimpleKalman(errorMeasure: 1, errorEstimate: 150, q: 0.9);

  List<MagnetometerEvent> _magnetometerValues = [];
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;

  @override
  void initState() {
    _magnetometerSubscription = magnetometerEvents.listen((event){
      setState((){
        _magnetometerValues = [event];
        _magnetometerValues.add(event);
      });
    });

    super.initState();
    _isMounted = true;
    _loadData();
    listeningState();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      description = prefs.getString('description');
    });
  }

  void listeningState() async {
    print('Listening to bluetooth state');
    await flutterBeacon.initializeAndCheckScanning;
    _streamBluetooth = flutterBeacon
        .bluetoothStateChanged()
        .listen((BluetoothState state) async {
      print('Bluetooth State: $state');
      if (state == BluetoothState.stateOn) {
        initScanBeacon();
      } else {
        _streamRanging!.pause();
      }
    });
  }

  void initScanBeacon() async {
    Timer.periodic(Duration(seconds: 5), (timer) async {
      await stopRead();

      double rss1 = lastRssis.isNotEmpty && lastRssis.length > 0
          ? lastRssis[0]!.toDouble()
          : 0.0;
      double rss2 = lastRssis.length > 1 ? lastRssis[1]!.toDouble() : 0.0;
      double rss3 = lastRssis.length > 2 ? lastRssis[2]!.toDouble() : 0.0;
      double magneticX = _magnetometerValues.last.x;
      double magneticY = _magnetometerValues.last.y;
      double magneticZ = _magnetometerValues.last.z;
      double magneticRssi = sqrt(pow(magneticX, 2) + pow(magneticY, 2) + pow(magneticZ, 2));

      List<int> magneticData = [magneticX.toInt(), magneticY.toInt(), magneticZ.toInt(), magneticRssi.toInt()];

      var data = {
        'rss1': rss1,
        'rss2': rss2,
        'rss3': rss3,
        'magneticX': magneticX,
        'magneticY': magneticY,
        'magneticZ': magneticZ,
        'magneticRssi': magneticRssi,
      };

      fetchData(data, magneticData);
    });
    startRead();
  }

  startRead() async {
    try {
      await platform.invokeMethod<String>('startListener');
      loadEvent();
    } on PlatformException catch (e) {
      print(e);
    }
  }

  double median(List<int> values) {
    if (values.isEmpty) return 0;
    values.sort();

    int middle = values.length ~/ 2;

    if (values.length % 2 == 1) {
      return values[middle].toDouble();
    } else {
      return ((values[middle - 1] + values[middle]) / 2).toDouble();
    }
  }

  double media(List<int> values) {
    if (values.isEmpty) return 0;
    int soma = values.reduce((a, b) => a + b);
    return soma / values.length;
  }

  List<int> rss1List = [];
  List<int> rss2List = [];
  List<int> rss3List = [];
  List<int> rss4List = [];

  Future<void> stopRead() async {
    double rss1Median = median(rss1List);
    double rss2Median = median(rss2List);
    double rss3Median = median(rss3List);
    double rss4Median = median(rss4List);

    print("Mediana RSS1: $rss1Median");
    print("Mediana RSS2: $rss2Median");
    print("Mediana RSS3: $rss3Median");

    int rss1 =
        rss1List.isNotEmpty && rss1List.length > 0 ? rss1Median.toInt() : 0;
    int rss2 =
        rss2List.isNotEmpty && rss2List.length > 0 ? rss2Median.toInt() : 0;
    int rss3 =
        rss3List.isNotEmpty && rss3List.length > 0 ? rss3Median.toInt() : 0;
    int rss4 =
        rss4List.isNotEmpty && rss4List.length > 0 ? rss4Median.toInt() : 0;

    lastRssis = [rss1, rss2, rss3, rss4];

    rss1List.clear();
    rss2List.clear();
    rss3List.clear();
    rss4List.clear();
  }

  void loadEvent() {
    try {
      eventChannel.receiveBroadcastStream().forEach((event) {
        if (event != null) {
          List<dynamic> dynamicList = event;
          rss1List.add(dynamicList.length > 0 ? dynamicList[0] : 0);
          rss2List.add(dynamicList.length > 1 ? dynamicList[1] : 0);
          rss3List.add(dynamicList.length > 2 ? dynamicList[2] : 0);
          rss4List.add(dynamicList.length > 3 ? dynamicList[3] : 0);
        }
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future<void> fetchData(Map<String, double> data2, List<int?> magneticData) async {
    if (!_isMounted) return;
    try {
      final response = await http.post(
        Uri.parse(
            'https://ble-fingerprinting-2369ef4e0fbf.herokuapp.com/predict'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(data2),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Acessar os valores de coords para "ble"
      final ble = data['ble'] as Map<String, dynamic>;
      final bleCoords = ble['coords'] as String;
      final bleCoordsValues =
          bleCoords.replaceAll('(', '').replaceAll(')', '').split(',');

      final bleX = int.parse(bleCoordsValues[0][0].trim());
      final bleY = int.parse(bleCoordsValues[0][2].trim());

      List<int?> bleWithMagnetic = lastRssis + magneticData;

      var new_data = {
        'rssis': bleWithMagnetic,
        'description': description,
        'coord_real': '$realX, $realY',
        'coord_estimated': '$bleX, $bleY',
      };

      postKnnMetrics(new_data);

      setState(() {
        currentX = bleX;
        currentY = bleY;
        fetchedData = data;
        ;
      });
    } catch (e) {
      throw Exception('Falha ao carregar os dados');
    }
  }

    Future<void> postKnnMetrics(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(
          'https://rei-dos-livros-api-f270d083e2b1.herokuapp.com/knn_metric'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      print('KNN Metrics posted');
    } else {
      throw Exception('Falha ao carregar os dados');
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
     _magnetometerSubscription.cancel();
    _streamRanging?.cancel();
    _streamBluetooth?.cancel();
  }

  bool isNullOrEmpty(String? value) {
    return value == null || value.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final int rows = 4;
    final int cols = 3;

    final arguments = (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{}) as Map;

    setState(() {
      realX = !isNullOrEmpty(arguments['x']) ? int.parse(arguments['x']) : 66;
      realY = !isNullOrEmpty(arguments['y']) ? int.parse(arguments['y']) : 66;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Position Page'),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  color: Colors.white.withOpacity(0.8),
                  child: Text(
                    'RSSIs: $lastRssis',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(10),
                  color: Colors.white.withOpacity(0.8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fetchedData.entries.map<Widget>((entry) {
                      final coords = entry.value['coords'];
                      final probability = entry.value['probability'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '${entry.key} - Coords: $coords, Probability: $probability',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}