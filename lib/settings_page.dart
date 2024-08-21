import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController descricaoController = TextEditingController();
  final TextEditingController beaconsFilterController = TextEditingController();
  static const platform = MethodChannel('samples.flutter.dev/beacons');

  String? savedDescricao;
  String? beaconsFilter;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedDescricao = prefs.getString('description');
      beaconsFilter = prefs.getString('beaconsFilter');
      descricaoController.text = savedDescricao ?? '';
      beaconsFilterController.text = beaconsFilter ?? '';
    });
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('description', descricaoController.text);
    await prefs.setString('beaconsFilter', beaconsFilterController.text);

    setState(() {
      savedDescricao = descricaoController.text;
      beaconsFilter = beaconsFilterController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dados salvos com sucesso!')),
    );

    try {
      await platform.invokeMethod('setBeaconsFilter', {'beaconsFilter': beaconsFilter ?? ''});
    } on PlatformException catch (e) {
      print("Failed to send rssis: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: descricaoController,
              decoration: InputDecoration(labelText: 'Descrição'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: beaconsFilterController,
              decoration: InputDecoration(labelText: 'Beacons Filter'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveData,
              child: Text('Salvar'),
            ),
            SizedBox(height: 16),
            if (savedDescricao != null && beaconsFilter != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Descrição Salva: $savedDescricao'),
                  Text('Filtro dos beacons Salvos: $beaconsFilter'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
