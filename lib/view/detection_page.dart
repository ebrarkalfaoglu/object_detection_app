import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  FlutterVision vision = FlutterVision();
  FlutterTts flutterTts = FlutterTts();
  SpeechToText speechToText = SpeechToText();
  CameraController? controller;
  List<Map<String, dynamic>> results = [];

  bool isLoaded = false;
  bool isDetecting = false;
  bool isPhotoMode = false;
  bool isListening = false;
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
    await flutterTts.setSpeechRate(0.35);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(0.9);
    await startListening();
    await flutterTts.awaitSpeakCompletion(true);

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
        confThreshold: 0.5,
        classThreshold: 0.5,
      );

      print(result);

      if (result.isNotEmpty) {
        results = result;

        String detectedObject = results.first["tag"];

        double x1 = results.first["box"][0];
        double x2 = results.first["box"][2];

        double centerX = (x1 + x2) / 2;
        double width = x2 - x1;

        double height =
    results.first["box"][3] -
    results.first["box"][1];

        double area = width * height;

        String distance = "";

        if (area > 120000) {
          distance = "very close";
        }
        else if (area > 50000) {
          distance = "nearby";
        } 
        else {
          distance = "far away";
        }

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

      String speech =
          "$detectedObject $direction and $distance";

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

  Future<void> startListening() async {
  bool available = await speechToText.initialize();

  if (available) {
    setState(() {
      isListening = true;
    });

    Future.delayed(
      const Duration(seconds: 30),
      () async {
        await speechToText.stop();

        setState(() {
          isListening = false;
        });
      },
);

    speechToText.listen(
      listenFor: const Duration(seconds: 30),

      onResult: (result) async {
        String spokenText =
          result.recognizedWords.toLowerCase();

        print("DUYULAN: $spokenText");

        if (
          spokenText.contains("take") &&
          spokenText.contains("photo")
    ) {
          print("PHOTO COMMAND DETECTED");

          await takePhotoAndDetect();
    }
  },
);
  }
}

  Future<void> takePhotoAndDetect() async {

  if (controller == null ||
      !controller!.value.isInitialized ||
      controller!.value.isTakingPicture) {
    return;
  }

  try {

    isPhotoMode = true;

    // STREAM DURSUN
    if (controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }

    // FOTO ÇEK
    final XFile picture =
        await controller!.takePicture();

    selectedImage = File(picture.path);

    results = [];

    // YOLO IMAGE
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

      await flutterTts.speak(detectedObject);
    }

    setState(() {});

    // STREAMİ GERİ BAŞLAT
    controller!.startImageStream((image) async {

      if (isDetecting || isPhotoMode) return;

      isDetecting = true;

      final result = await vision.yoloOnFrame(
        bytesList:
            image.planes.map((plane) => plane.bytes).toList(),

        imageHeight: image.height,
        imageWidth: image.width,

        iouThreshold: 0.2,
        confThreshold: 0.5,
        classThreshold: 0.5,
      );

      if (result.isNotEmpty) {
        results = result;
      }

      setState(() {});

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      isDetecting = false;
    });

  } catch (e) {
    print("PHOTO ERROR: $e");
  }

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
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        onPressed: takePhotoAndDetect,
        child: const Icon(Icons.camera_alt),
      ),

      body: SafeArea(
        child: Stack( 
        children: [
          selectedImage != null
            ? Image.file(
              selectedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
      )
    : SizedBox.expand(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller!.value.previewSize!.height,
        height: controller!.value.previewSize!.width,
        child: CameraPreview(controller!),
      ),
    ),
  ),

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
                    color: Colors.cyanAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),

                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    color: Colors.cyanAccent,
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
        ],
      ),
      ), 
    );
  }
}