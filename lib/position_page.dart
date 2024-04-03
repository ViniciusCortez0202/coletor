import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

class PositionPage extends StatefulWidget {
  const PositionPage({Key? key}) : super(key: key);

  @override
  _PositionPageState createState() => _PositionPageState();
}

class _PositionPageState extends State<PositionPage> {
  int currentX = 0;
  int currentY = 0;
  final List<String> allowedUUIDs = ["00:FA:B6:1D:DE:07", "00:FA:B6:1D:DD:F8", "00:FA:B6:12:E8:86"];
  List<BluetoothDevice> _systemDevices = [];
  
  List<ScanResult> _scanResults = [];
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  Map<String, List<int>> groupedResults = {};
  bool _isScanning = false;
  Duration timeToScan = const Duration(seconds: 7);
  late double duration;
  late Timer _timer;

  @override
  void initState() {
    duration = timeToScan.inSeconds.toDouble();
    super.initState();
    
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (!_isScanning) {
        startScan();
      }

      print("NOVA RELAÇÃO:");
      print(groupedResults);


      List<int?> averages = [];

      groupedResults.values.forEach((list) {
        double sum = 0;
        list.forEach((num) {
          sum += num;
        });
        double average = sum / list.length;
        averages.add(average.toInt());
      });

   
        // Verifica se o array tem menos de três elementos
      if (averages.length < 3) {
        // Calcula o número de elementos que precisam ser adicionados
        int elementsToAdd = 3 - averages.length;
        
        // Adiciona null para completar o averages
        for (int i = 0; i < elementsToAdd; i++) {
          averages.add(null);
        }
      }
      print("Médias: $averages");

      fetchData(averages);

      groupedResults.clear();
      averages.clear();
    });

    print("-----------------");
    _adapterStateStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      results.forEach((element) {
        if (allowedUUIDs.contains(element.device.id.toString())) {
        _scanResults.add(element);
        }
      });
    }, onError: (e) {});

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
    });
  }

  Future<void> fetchData(List<int?> rssiValues) async {
    final response = await http.get(
      Uri.parse('https://rei-dos-livros-api-f270d083e2b1.herokuapp.com/knn_position?rssis=${rssiValues.join(",")}'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    print("CHEGANDO AQUIIIIII!");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      setState(() {
        print("OLA TA CHEGANDO AQUI O RESULTADO------");
        print(data);
        currentX = data[0];
        currentY = data[1];
      });
    } else {
      throw Exception('Falha ao carregar os dados');
    }
  }

  Future<void> startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: timeToScan);
      duration = timeToScan.inSeconds.toDouble();
      print('Scanning for devices...');
    } catch (e) {
      print("Erro ao iniciar o scan: $e");
    }

    _scanResults.clear();

  _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
    results.forEach((element) {
      if (allowedUUIDs.contains(element.device.id.toString())) {
        String uuid = element.device.id.toString();
        int rssiValue = element.rssi; 

        if (groupedResults.containsKey(uuid)) {
          groupedResults[uuid]!.add(rssiValue);
        } else {
          groupedResults[uuid] = [rssiValue];
        }
      }
    });

  }, onError: (e) {});
  }


  @override
  Widget build(BuildContext context) {
    final int rows = 4;
    final int cols = 3;

    return Scaffold(
      appBar: AppBar(
        title: Text('Position Page'),
      ),
      body: Center(
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
                color: isCurrentPosition ? Colors.red : Colors.blue, 
                child: Center(
                  child: Text(
                    '($col, $row)',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
