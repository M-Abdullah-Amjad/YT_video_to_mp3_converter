import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube to Audio Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _youtubeUrlController = TextEditingController();
  bool _isLoading = false;
  bool _isDownloading = false;
  String _loadingMessage = "";
  StreamSubscription? _downloadSubscription;

  Future<void> _downloadAudio() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _isDownloading = true;
      _loadingMessage = "Downloading...";
    });

    // Request permissions
    if (await Permission.storage.request().isGranted) {
      final yt = YoutubeExplode();
      final url = _youtubeUrlController.text;

      try {
        // Get video info
        var video = await yt.videos.get(url);

        // Get audio stream manifest
        var manifest = await yt.videos.streamsClient.getManifest(video.id);

        // Attempt to get the highest bitrate audio stream
        var audioStream = manifest.audioOnly.withHighestBitrate();

        // If the highest bitrate audio is not available, try other audio streams
        if (audioStream == null) {
          try {
            audioStream = manifest.audioOnly.firstWhere(
                  (stream) => stream.container == StreamContainer.mp4,
            );
          } catch (e) {
            throw Exception("No compatible audio streams found.");
          }
        }

        // Check if an audio stream was found
        if (audioStream == null) {
          throw Exception("No compatible audio streams available.");
        }

        // Get download directory (using a public directory for Music)
        final directory = Directory('/storage/emulated/0/Music');
        String sanitizedFileName =
        video.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final filePath = '${directory.path}/$sanitizedFileName.mp3';

        // Ensure the directory exists
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        // Download the audio file
        var fileStream = yt.videos.streamsClient.get(audioStream);
        var file = File(filePath);
        var output = file.openWrite();

        _downloadSubscription = fileStream.listen(
              (chunk) {
            output.add(chunk);
          },
          onDone: () async {
            await output.flush();
            await output.close();

            // Notify system about the new file
            await _notifyMediaScanner(filePath);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Audio downloaded: $filePath')),
            );

            setState(() {
              _isLoading = false;
              _isDownloading = false;
            });

            _youtubeUrlController.clear();
          },
          onError: (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to download audio: $e')),
            );
            print('Failed to download audio: $e');

            setState(() {
              _isLoading = false;
              _isDownloading = false;
            });
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download audio: $e')),
        );
        print('Failed to download audio: $e');

        setState(() {
          _isLoading = false;
          _isDownloading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied')),
      );
      setState(() {
        _isLoading = false;
        _isDownloading = false;
      });
    }
  }

  Future<void> _notifyMediaScanner(String filePath) async {
    try {
      await MethodChannel('com.example.youtube_to_mp3/mediaplayer')
          .invokeMethod('scanFile', {'path': filePath});
    } on PlatformException catch (e) {
      print("Failed to notify media scanner: '${e.message}'.");
    }
  }

  void _clearTextField() {
    _youtubeUrlController.clear();
  }

  void _stopDownload() {
    _downloadSubscription?.cancel();
    setState(() {
      _isLoading = false;
      _isDownloading = false;
      _loadingMessage = "";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading stopped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.red.shade900,
        title: Text("YouTube to Audio Converter"),
        actions: [
          IconButton(
            onPressed: () => exit(0),
            icon: Icon(Icons.exit_to_app),
          )
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 120, left: 30, right: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _youtubeUrlController,
                    decoration: InputDecoration(
                      labelText: 'YouTube Video URL',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.1),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _downloadAudio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Convert & Download Audio",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _clearTextField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Clear Field",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  if (_isDownloading) ...[
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _stopDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Stop Download",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading)
            Center(
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 10),
                    Text(_loadingMessage, style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Powered by codecamp.website",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    "Owner M. Abdullah Amjad",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
