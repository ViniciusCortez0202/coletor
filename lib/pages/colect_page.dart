import 'package:flutter/material.dart';

class ColectPage extends StatefulWidget {
  const ColectPage({super.key});

  @override
  State<ColectPage> createState() => _ColectPageState();
}

class _ColectPageState extends State<ColectPage> {
  late TextEditingController controllerX;
  late TextEditingController controllerY;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    controllerX = TextEditingController();
    controllerY = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Coletor")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: TextField(
                      decoration:
                          const InputDecoration(hintText: "Coordenada X"),
                      keyboardType: TextInputType.number,
                      controller: controllerX,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: TextField(
                      decoration:
                          const InputDecoration(hintText: "Coordenada Y"),
                      keyboardType: TextInputType.number,
                      controller: controllerY,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                      onPressed: () { 
                        Navigator.of(context).pushNamed('/position', arguments: {
                          'x': controllerX.text,
                          'y': controllerY.text
                        });
                      }, child: const Text("Estimar posição")),
                  const SizedBox(width: 20),
                  FilledButton(
                      onPressed: () {
                        if (controllerX.text.trim().isEmpty ||
                            controllerY.text.trim().isEmpty) {
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => AlertDialog(
                                    title: const Text(
                                        "As coordenada não podem ser vazias"),
                                    actions: [
                                      ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text("ok"))
                                    ],
                                  ));

                          return;
                        }
                        Navigator.of(context).pushNamed('/colect', arguments: {
                          'x': controllerX.text,
                          'y': controllerY.text
                        });
                      },
                      child: const Text("Iniciar coleta"))
                ],
              )
            ]),
      ),
    );
  }
}
