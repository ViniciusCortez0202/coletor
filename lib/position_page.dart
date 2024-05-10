import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:simple_kalman/simple_kalman.dart';

class PositionPage extends StatefulWidget {
  const PositionPage({Key? key}) : super(key: key);

  @override
  _PositionPageState createState() => _PositionPageState();
}

class _PositionPageState extends State<PositionPage> {
  int currentX = 0;
  int currentY = 0;
  bool _isMounted = false;
  int time_seconds = 10;

  List<List<int?>> rssiValuesGeral = [];

  static const platform = MethodChannel('samples.flutter.dev/beacons');

  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;
  final kalman = SimpleKalman(errorMeasure: 1, errorEstimate: 150, q: 0.9);

  @override
  void initState() {
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
  initScanBeacon() async {
    startRead();
 
    Timer.periodic(Duration(seconds: 5), (timer) {
        stopRead();
        List<int> positions = [0, 1, 2];
        List<int> medianValues = calculateMedianForPositions(rssiValuesGeral, positions);
        print("MEDIAN VALUES: $medianValues");
        rssiValuesGeral.clear();
        fetchData(medianValues);
        startRead();
    });
  }

    startRead() async {
    try {
      print("iniciando dnv??");
      await platform.invokeMethod<String>('startListener');
    } on PlatformException catch (e) {
      print(e);
    }
  }

  List<int> calculateMedianForPositions(List<List<int?>> rssisList, List<int> positions) {
  final List<int> medians = [];

  for (int position in positions) {
    final List<int> values = [];

    for (final rssis in rssisList) {
      if (position < rssis.length) {
        values.add(rssis[position] ?? 0); // Substitui valores nulos por 0
      }
    }

    if (values.isNotEmpty) {
      values.sort();

      final int size = values.length;
      if (size % 2 == 0) {
        final int mid = size ~/ 2;
        medians.add((values[mid - 1] + values[mid]) ~/ 2);
      } else {
        final int mid = size ~/ 2;
        medians.add(values[mid]);
      }
    } else {
      medians.add(0); // Adiciona 0 se não houver valores
    }
  }

  return medians;
}

  stopRead() async {
    try {
      final result = await platform.invokeMethod<List>('stopListener');

      if (result != null) {
      for (var map in result) {
         List<int> valuesList = map.values.map<int>((value) => int.tryParse(value.toString()) ?? 0).toList();

          while (valuesList.length < 3) {
            valuesList.add(0);
          }
          print("RSSI VALUES: $valuesList");
          rssiValuesGeral.add(valuesList);
          }
      }
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future<void> fetchData(List<int?> rssiValues) async {
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
    _streamRanging?.cancel();
    _streamBluetooth?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final int rows = 12;
    final int cols = 6;

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

            final bool isCurrentPosition = col == currentX && row == currentY;

            return GestureDetector(
              onTap: () {
                setState(() {
                  currentX = col;
                  currentY = row;
                });
              },
              child: Container(
                margin: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCurrentPosition ? Colors.red : Colors.white,
                  shape: BoxShape.circle,
                ),
                height: 50,  // Tamanho da bola (diâmetro)
                width: 50,   // Mantém a largura e a altura iguais para formar um círculo perfeito
              ),
            );
          },
        ),
      ),
      Opacity(
        opacity: 0.8,  // Ajuste a opacidade conforme necessário para tornar a imagem mais transparente
        child: Center(
          child: Image.asset(
            'assets/images/teste.png',  // Certifique-se de que o caminho esteja correto
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
        ),
      ),
    ],
  ),
);
  }
}
