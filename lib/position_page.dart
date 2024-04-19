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

class PositionPage extends StatefulWidget {
  const PositionPage({Key? key}) : super(key: key);

  @override
  _PositionPageState createState() => _PositionPageState();
}

class _PositionPageState extends State<PositionPage> {
  int currentX = 0;
  int currentY = 0;
  final List<String> allowedUUIDs = [
    "00:FA:B6:1D:DE:07",
    "00:FA:B6:1D:DD:F8",
    "00:FA:B6:12:E8:86"
  ];
  String beaconUUID = 'F7826DA6-4FA2-4E98-8024-BC5B71E0893E';
  StreamSubscription<RangingResult>? _streamRanging;
  StreamSubscription<BluetoothState>? _streamBluetooth;

  @override
  void initState() {
    super.initState();

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
        print("TA CHEGANDO AQUI OH.....");
        _streamRanging!.pause();
      }
    });
  }

  initScanBeacon() async {
    final regions = <Region>[];

    regions.add(
        Region(identifier: 'com.beacon', proximityUUID: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E"));

    _streamRanging = flutterBeacon.ranging(regions).listen((RangingResult result) {
      if (result != null && result.beacons.isNotEmpty) {
        debugPrint('Found beacons: ${result.beacons.length}');
        List<int> rssis = result.beacons.map((beacon) => beacon.rssi).toList();
        debugPrint('RSSIs: $rssis');
    } else {
      debugPrint('No beacons found');
    }
    });
  }

  // Future<void> fetchData(List<int?> rssiValues) async {
  //   final response = await http.get(
  //     Uri.parse(
  //         'https://rei-dos-livros-api-f270d083e2b1.herokuapp.com/knn_position?rssis=${rssiValues.join(",")}'),
  //     headers: {
  //       'Content-Type': 'application/json',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body) as List;
  //     setState(() {
  //       currentX = data[0];
  //       currentY = data[1];
  //     });
  //   } else {
  //     throw Exception('Falha ao carregar os dados');
  //   }
  // }

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
