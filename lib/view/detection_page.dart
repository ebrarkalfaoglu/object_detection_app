import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  FlutterVision vision = FlutterVision();
  FlutterTts flutterTts = FlutterTts();
  CameraController? controller;
  List<Map<String, dynamic>> results = [];

  bool isLoaded = false;
  bool isDetecting = false;
  String lastSpoken = "";

  @override
  void initState() {
    super.initState();
    initEverything();
  }

  Future<void> initEverything() async {
    await loadModel();

    final cameras = await availableCameras();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    controller!.startImageStream((image) async {
      if (isDetecting) return;

      isDetecting = true;

      final result = await vision.yoloOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.2,
        confThreshold: 0.1,
        classThreshold: 0.1,
      );

      print(result);

      if (result.isNotEmpty) {
        results = result;

        String detectedObject = results.first["tag"];

        if (detectedObject != lastSpoken) {
          lastSpoken = detectedObject;
          await flutterTts.speak(detectedObject);
        }
      }

      setState(() {});

      await Future.delayed(const Duration(milliseconds: 300));

      isDetecting = false;
    });

    isLoaded = true;
    setState(() {});
  }

  Future<void> loadModel() async {
    await vision.loadYoloModel(
      labels: 'assets/labels.txt',
      modelPath: 'assets/yolov5.tflite',
      modelVersion: "yolov5",
      quantization: true,
      numThreads: 2,
      useGpu: false,
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded || controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Real-Time Detection"),
      ),
      body: Stack(
        children: [
          CameraPreview(controller!),

          // BOUNDING BOX
          ...results.map((result) {
            return Positioned(
              left: result["box"][0],

              top: result["box"][1],

              width:
                  result["box"][2] - result["box"][0],

              height:
                  result["box"][3] - result["box"][1],

              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red,
                    width: 3,
                  ),
                ),

                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.all(4),

                    child: Text(
                      "${result["tag"]} "
                      "${(result["box"][4] * 100).toStringAsFixed(0)}%",

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          Positioned(
            top: 50,
            left: 20,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),

              child: Text(
                results.isNotEmpty
                    ? results.first["tag"]
                    : "Algılanmadı",

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}