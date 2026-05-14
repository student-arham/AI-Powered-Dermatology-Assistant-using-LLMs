import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UploadPage(),
    );
  }
}

class UploadPage extends StatefulWidget {
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  Uint8List? imageBytes;

  String fileName = "";

  final picker = ImagePicker();

  String result = "";

  String condition = "";

  String confidence = "";

  bool loading = false;

  // ======================
  // SPEECH TO TEXT
  // ======================

  late stt.SpeechToText speech;

  bool isListening = false;

  String voiceText = "";

  // ======================
  // TEXT TO SPEECH
  // ======================

  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    speech = stt.SpeechToText();
  }

  // ======================
  // PICK IMAGE
  // ======================

  Future pickImage() async {
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();

      setState(() {
        imageBytes = bytes;

        fileName = pickedFile.name;
      });
    }
  }

  // ======================
  // START LISTENING
  // ======================

  Future startListening() async {
    bool available = await speech.initialize();

    if (available) {
      setState(() {
        isListening = true;
      });

      speech.listen(
        onResult: (result) {
          setState(() {
            voiceText = result.recognizedWords;
          });
        },
      );
    }
  }

  // ======================
  // STOP LISTENING
  // ======================

  Future stopListening() async {
    await speech.stop();

    setState(() {
      isListening = false;
    });
  }

  // ======================
  // SPEAK RESULT
  // ======================

  Future speakText(String text) async {
    await flutterTts.speak(text);
  }

  // ======================
  // UPLOAD IMAGE
  // ======================

  Future uploadImage() async {
    if (imageBytes == null) return;

    setState(() {
      loading = true;
    });

    try {
      // ======================
      // WEB URL
      // ======================

      String url;

      if (kIsWeb) {
        url = "http://127.0.0.1:5000/upload";
      } else {
        url = "http://10.0.2.2:5000/upload";
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(url),
      );

      // IMAGE
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes!,
          filename: fileName,
        ),
      );

      // VOICE TEXT
      request.fields['voice_query'] = voiceText;

      var response = await request.send();

      var responseData = await response.stream.bytesToString();

      var jsonData = jsonDecode(responseData);

      setState(() {
        condition = jsonData["condition"];

        confidence = jsonData["confidence"].toString();

        result = jsonData["report"];
      });

      speakText(result);
    } catch (e) {
      setState(() {
        result = "ERROR: $e";
      });
    }

    setState(() {
      loading = false;
    });
  }

  // ======================
  // UI
  // ======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "AI Medical Assistant",
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),

              // ======================
              // IMAGE
              // ======================

              imageBytes != null
                  ? Image.memory(
                      imageBytes!,
                      height: 250,
                    )
                  : Text(
                      "No Image Selected",
                    ),

              SizedBox(height: 30),

              // ======================
              // PICK IMAGE
              // ======================

              ElevatedButton(
                onPressed: pickImage,
                child: Text(
                  "Pick Image",
                ),
              ),

              SizedBox(height: 30),

              // ======================
              // VOICE
              // ======================

              Text(
                "Voice Query",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                voiceText.isEmpty ? "Speak something..." : voiceText,
              ),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: isListening ? stopListening : startListening,
                child: Text(
                  isListening ? "Stop Listening" : "Start Speaking",
                ),
              ),

              SizedBox(height: 30),

              // ======================
              // UPLOAD
              // ======================

              ElevatedButton(
                onPressed: loading ? null : uploadImage,
                child: loading
                    ? CircularProgressIndicator()
                    : Text(
                        "Analyze Image",
                      ),
              ),

              SizedBox(height: 40),

              // ======================
              // RESULT
              // ======================

              if (condition.isNotEmpty)
                Column(
                  children: [
                    Text(
                      "Condition",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      condition,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Confidence: $confidence %",
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 30),
                    Text(
                      result,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
