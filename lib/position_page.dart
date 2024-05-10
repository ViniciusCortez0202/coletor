import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_settings/open_settings.dart';
import 'package:coletor/permission_services.dart';
import 'package:coletor/controller.dart';
import 'package:coletor/permission_services.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final List<String> allowedUUIDs = [
    "00:FA:B6:1D:DE:07",
    "00:FA:B6:1D:DD:F8",
    "00:FA:B6:12:E8:86"
  ];
  String beaconUUID = 'F7826DA6-4FA2-4E98-8024-BC5B71E0893E';
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
  List<int> lastRssis = [];

  List<int> rss1Values = [];
  List<int> rss2Values = [];
  List<int> rss3Values = [];

  initScanBeacon() async {
    final regions = <Region>[];

    regions.add(
        Region(identifier: 'com.beacon', proximityUUID: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E"));

    _streamRanging = flutterBeacon.ranging(regions).listen((RangingResult result) {
      if (result != null && result.beacons.isNotEmpty) {
        debugPrint('Found beacons: ${result.beacons.length}');
        List<int> rssis = result.beacons.map((beacon) => beacon.rssi).toList();

        //List<double> filteredRssis = rssis.map((rssi) => kalman.filtered(rssi.toDouble())).toList();

        //List<int> filteredRssisInt = filteredRssis.map((value) => value.toInt()).toList();

        // debugPrint('RSSIs: $rssis');
        // debugPrint('Filtered RSSIs Int: $filteredRssisInt');
        
        while (rssis.length < 3) {
          rssis.add(0);
        }
        //lastRssis = filteredRssisInt;

        rss1Values.add(rssis[0]);
        rss2Values.add(rssis[1]);
        rss3Values.add(rssis[2]);

    } else {
      debugPrint('No beacons found');
    }
    });

    Timer.periodic(Duration(seconds: 10), (timer) {
        int averageRss1 = (rss1Values.reduce((a, b) => a + b) / rss1Values.length).round();
        int averageRss2 = (rss2Values.reduce((a, b) => a + b) / rss2Values.length).round();
        int averageRss3 = (rss3Values.reduce((a, b) => a + b) / rss3Values.length).round();

        List<int> averageValues = [averageRss1, averageRss2, averageRss3];
        print("Average RSSIs: $averageValues");
        fetchData(averageValues);
        //lastRssis.clear(); 
        rss1Values.clear();
        rss2Values.clear();
        rss3Values.clear();
    });
  }

  List<int> calculateMedian(List<List<int>> rssisList) {
  final List<int> medians = [];

  // Itera sobre as posições dos RSSIs
  for (int i = 0; i < rssisList[0].length; i++) {
    final List<int> values = [];

    // Coleta os RSSIs na mesma posição de cada array interno
    for (final rssis in rssisList) {
      values.add(rssis[i]);
    }

    // Ordena os valores de RSSI
    values.sort();

    final int size = values.length;
    if (size % 2 == 0) {
      // Se houver um número par de valores, a mediana é a média dos dois valores do meio
      final int mid = size ~/ 2;
      medians.add((values[mid - 1] + values[mid]) ~/ 2);
    } else {
      // Se houver um número ímpar de valores, a mediana é o valor do meio
      final int mid = size ~/ 2;
      medians.add(values[mid]);
    }
  }

  return medians;
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
