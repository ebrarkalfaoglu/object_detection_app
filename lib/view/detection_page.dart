import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
  bool isPhotoMode = false;
  File? selectedImage;
  String lastSpoken = "";

  @override
  void initState() {
    super.initState();
    initEverything();
  }

  Future<void> initEverything() async {
    await loadModel();

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    final cameras = await availableCameras();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    controller!.startImageStream((image) async {
      if (isDetecting || isPhotoMode) return;

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

        double x1 = results.first["box"][0];
        double x2 = results.first["box"][2];

        double centerX = (x1 + x2) / 2;

        String direction = "";

        double screenWidth = MediaQuery.of(context).size.width;

        if (centerX < screenWidth * 0.33) {
          direction = "on the left";
        } 
        else if (centerX > screenWidth * 0.66) {
          direction = "on the right";
        }
        else {
          direction = "ahead";
        }

      String speech = "$detectedObject $direction";

        if (detectedObject != lastSpoken) {
          lastSpoken = detectedObject;
          await flutterTts.speak(speech);
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

  Future<void> pickImageAndDetect() async {
  final picker = ImagePicker();

  final pickedFile = await picker.pickImage(
    source: ImageSource.camera,
  );

  if (pickedFile == null) return;

  if (!controller!.value.isStreamingImages) {
    await controller!.startImageStream((image) async {});
  }

  await controller?.stopImageStream();
  
  results = [];

  selectedImage = File(pickedFile.path);
  
  isPhotoMode = true;
  final result = await vision.yoloOnImage(
    bytesList: await selectedImage!.readAsBytes(),
    imageHeight: 640,
    imageWidth: 640,
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
  isPhotoMode = false;
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

      floatingActionButton: FloatingActionButton(
        onPressed: pickImageAndDetect,
        child: const Icon(Icons.camera_alt),
      ),

      body: Stack(
        children: [
          selectedImage != null
            ? Image.file(
              selectedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
      )
    : CameraPreview(controller!),

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