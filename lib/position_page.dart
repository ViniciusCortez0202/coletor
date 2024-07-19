import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:simple_kalman/simple_kalman.dart';

// Pacotes para a obtenção dos dados magéticos e cálculo da RSSI magnética
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

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

  List<int> lastRssis = [];

  static const platform = MethodChannel('samples.flutter.dev/beacons');

  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;
  final kalman = SimpleKalman(errorMeasure: 1, errorEstimate: 150, q: 0.9);

  //Lista de valores do sensor magnético
  List<MagnetometerEvent> _magnetometerValues = [];
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;

  @override
  void initState() {
    _magnetometerSubscription = magnetometerEvents.listen((event) {
      setState(() {
        _magnetometerValues = [event];
        _magnetometerValues.add(event);
      });
    });

    super.initState();
    _isMounted = true;
    listeningState();
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
      await performScan();
    });
  }

  Future<void> performScan() async {
    await stopRead();

    double rss1 = lastRssis.isNotEmpty && lastRssis.length > 0
        ? lastRssis[0].toDouble()
        : 0.0;
    double rss2 = lastRssis.length > 1 ? lastRssis[1].toDouble() : 0.0;
    double rss3 = lastRssis.length > 2 ? lastRssis[2].toDouble() : 0.0;
    double magneticX =
        _magnetometerValues.isNotEmpty ? _magnetometerValues.last.x : 0.0;
    double magneticY =
        _magnetometerValues.isNotEmpty ? _magnetometerValues.last.y : 0.0;
    double magneticZ =
        _magnetometerValues.isNotEmpty ? _magnetometerValues.last.z : 0.0;
    double magneticRssi =
        sqrt(pow(magneticX, 2) + pow(magneticY, 2) + pow(magneticZ, 2));

    var data = {
      'rss1': rss1,
      'rss2': rss2,
      'rss3': rss3,
      'magneticX': magneticX,
      'magneticY': magneticY,
      'magneticZ': magneticZ,
      'magneticRssi': magneticRssi
    };

    fetchData(data);

    // Restart the read process for the next interval
    await startRead();
  }

  startRead() async {
    try {
      await platform.invokeMethod<String>('startListener');
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
    try {
      final result = await platform.invokeMethod<List<dynamic>>('stopListener');

      if (result != null) {
        for (var i = 0; i < result.length; i++) {
          List<dynamic> dynamicList = result[i];
          List<int> valuesListAsInt = dynamicList.map((e) => e as int).toList();

          rss1List.add(valuesListAsInt[0]);
          rss2List.add(valuesListAsInt[1]);
          rss3List.add(valuesListAsInt[2]);
          //rss4List.add(valuesListAsInt[3]);
        }
      }
    } on PlatformException catch (e) {
      print(e);
    }

    double rss1Median = median(rss1List);
    double rss2Median = median(rss2List);
    double rss3Median = median(rss3List);
    double rss4Median = median(rss4List);

    // print("RSS1: $rss1List");
    // print("RSS2: $rss2List");
    // print("RSS3: $rss3List");

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

    lastRssis = [rss1, rss2, rss3];

    rss1List.clear();
    rss2List.clear();
    rss3List.clear();
    rss4List.clear();
  }

  Future<void> fetchData(Map<String, double> data) async {
    if (!_isMounted) return;
    final response = await http.post(
      Uri.parse(
          'https://ble-fingerprinting-2369ef4e0fbf.herokuapp.com/predict'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Acessar os valores de coords para "ble"
      final ble = data['ble'] as Map<String, dynamic>;
      final bleCoords = ble['coords'] as String;
      final bleCoordsValues =
          bleCoords.replaceAll('(', '').replaceAll(')', '').split(',');

      final bleX = int.parse(bleCoordsValues[0][0].trim());
      final bleY = int.parse(bleCoordsValues[0][2].trim());

      

      var new_data = {
        'rssis': lastRssis,
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
    } else {
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

  Future<void> fetchDataV2(List<int?> rssiValues) async {
    if (!_isMounted) return;

    final response = await http.get(
      Uri.parse(
          'https://rei-dos-livros-api-f270d083e2b1.herokuapp.com/knn_position?rssis=${rssiValues.join(",")}'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print("DATA: $data ");
      setState(() {
        currentX = data[0];
        currentY = data[1];
      });
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

  @override
  Widget build(BuildContext context) {
    final int rows = 4;
    final int cols = 3;
    final arguments = (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{}) as Map;

    setState(() {
      realX = int.parse(arguments['x']);
      realY = int.parse(arguments['y']);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Position Page'),
      ),
      body: Stack(
        children: [
          // Center(
          //   child: GridView.builder(
          //     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          //       crossAxisCount: cols,
          //     ),
          //     itemCount: rows * cols,
          //     itemBuilder: (BuildContext context, int index) {
          //       final int row = index ~/ cols;
          //       final int col = index % cols;

          //       final bool isCurrentPosition = row == currentX && col == currentY;

          //       return GestureDetector(
          //         onTap: () {
          //           setState(() {
          //             currentX = row;
          //             currentY = col;
          //           });
          //         },
          //         child: Container(
          //           margin: EdgeInsets.all(4),
          //           decoration: BoxDecoration(
          //             color: isCurrentPosition ? Colors.red : Colors.blue,
          //             shape: BoxShape.rectangle,
          //           ),
          //           height: 50,  // Tamanho da bola (diâmetro)
          //           width: 50,
          //           child: Center(
          //             child: Text(
          //               '($row, $col)',
          //               style: TextStyle(
          //                 color: Colors.white,  // Cor do texto
          //                 fontSize: 7,        // Tamanho do texto
          //               ),
          //             ),
          //           ),
          //         ),
          //       );
          //     },
          //   ),
          // ),
          // Opacity(
          //   opacity: 0.8,  // Ajuste a opacidade conforme necessário para tornar a imagem mais transparente
          //   child: Center(
          //     child: Image.asset(
          //       'assets/images/teste.png',  // Certifique-se de que o caminho esteja correto
          //       fit: BoxFit.cover,
          //       height: double.infinity,
          //       width: double.infinity,
          //     ),
          //   ),
          // ),
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
