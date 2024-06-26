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
  bool _isMounted = false;
  int time_seconds = 6;

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
    _magnetometerSubscription = magnetometerEvents.listen((event){
      setState((){
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
    _streamBluetooth = flutterBeacon.bluetoothStateChanged().listen((BluetoothState state) async {
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

      double rss1 = lastRssis.isNotEmpty && lastRssis.length > 0 ? lastRssis[0].toDouble() : 0.0;
      double rss2 = lastRssis.length > 1 ? lastRssis[1].toDouble() : 0.0;
      double rss3 = lastRssis.length > 2 ? lastRssis[2].toDouble() : 0.0;
      double magneticX = _magnetometerValues.last.x;
      double magneticY = _magnetometerValues.last.y;
      double magneticZ = _magnetometerValues.last.z;
      double magneticRssi = sqrt(pow(magneticX, 2) + pow(magneticY, 2) + pow(magneticZ, 2));

      var data = {
        'rss1': rss1,
        'rss2': rss2,
        'rss3': rss3,
        'magneticX': magneticX,
        'magneticY': magneticY,
        'magneticZ': magneticZ,
        'magneticRssi': magneticRssi
      };

      print("ENVIANDO PARA API: $data");
      fetchDataV2(lastRssis);

      // Restart the read process for the next interval
      startRead();
    });

    // Start the initial read
    startRead();
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

  List<int> rss1List = [];
  List<int> rss2List = [];
  List<int> rss3List = [];


  Future<void> stopRead() async {
    try {
      final result = await platform.invokeMethod<List>('stopListener');
      if (result != null) {
      for (var map in result) {
         List<int> valuesList = map.values.map<int>((value) => int.tryParse(value.toString()) ?? 0).toList();

          while (valuesList.length < 3) {
            valuesList.add(0);
          }
          rss1List.add(valuesList[0]);
          rss2List.add(valuesList[1]);
          rss3List.add(valuesList[2]);
          }
      }
    } on PlatformException catch (e) {
      print(e);
    }

    double rss1Median = median(rss1List);
    double rss2Median = median(rss2List);
    double rss3Median = median(rss3List);

    print("RSS1: $rss1List");
    print("RSS2: $rss2List");
    print("RSS3: $rss3List");

    print("Mediana RSS1: $rss1Median");
    print("Mediana RSS2: $rss2Median");
    print("Mediana RSS3: $rss3Median");


    int rss1 = rss1List.isNotEmpty && rss1List.length > 0 ? rss1List.last.toInt() : 0;
    int rss2 = rss2List.isNotEmpty && rss2List.length > 0 ? rss2List.last.toInt() : 0;
    int rss3 = rss3List.isNotEmpty && rss3List.length > 0 ? rss3List.last.toInt() : 0;

    lastRssis = [rss1, rss2, rss3];
  
    rss1List.clear();
    rss2List.clear();
    rss3List.clear();
  }

  Future<void> fetchData(Map<String, double> data) async {
    if (!_isMounted) return;
    final response = await http.post(
      Uri.parse('https://ble-fingerprinting-2369ef4e0fbf.herokuapp.com/predict'),
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
        final bleCoordsValues = bleCoords.replaceAll('(', '').replaceAll(')', '').split(',');
        final bleX = int.parse(bleCoordsValues[0].trim());
        final bleY = int.parse(bleCoordsValues[1].trim());

        print("BLE Coords: x = $bleX, y = $bleY");

        // Acessar os valores de coords para "ble_mag"
        final bleMag = data['ble_mag'] as Map<String, dynamic>;
        final bleMagCoords = bleMag['coords'] as String;
        final bleMagCoordsValues = bleMagCoords.replaceAll('(', '').replaceAll(')', '').split(',');
        final bleMagX = int.parse(bleMagCoordsValues[0].trim());
        final bleMagY = int.parse(bleMagCoordsValues[1].trim());

        print("BLE Mag Coords: x = $bleMagX, y = $bleMagY");

      setState(() {
        currentX = bleX;
        currentY = bleY;
      });
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
    final int rows = 9;
    final int cols = 4;

return Scaffold(
  appBar: AppBar(
    title: Text('Position Page'),
  ),
  body: Stack(
    children: [
      Center(
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
          ),
          itemCount: rows * cols,
          itemBuilder: (BuildContext context, int index) {
            final int row = index ~/ cols;
            final int col = index % cols;

            final bool isCurrentPosition = row == currentX && col == currentY;

            return GestureDetector(
              onTap: () {
                setState(() {
                  currentX = row;
                  currentY = col;
                });
              },
              child: Container(
                margin: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCurrentPosition ? Colors.red : Colors.blue,
                  shape: BoxShape.rectangle,
                ),
                height: 50,  // Tamanho da bola (diâmetro)
                width: 50,  
                child: Center(
                  child: Text(
                    '($row, $col)',
                    style: TextStyle(
                      color: Colors.white,  // Cor do texto
                      fontSize: 7,        // Tamanho do texto
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
    ],
  ),
);
  }
}
