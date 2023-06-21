
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

class Storage extends StatefulWidget {

  const Storage({super.key});  

  @override
  State<Storage> createState() => _StorageState();
  
}

class _StorageState extends State<Storage> {
 
  List<Reference> videoRefs = []; // Store the video references from Firebase Storage

  @override
  void initState() {
    super.initState();
    loadVideos();
  }

  Future<void> loadVideos() async {
    // Get the list of video references from Firebase Storage
    ListResult result = await FirebaseStorage.instance.ref().listAll();
    setState(() {
      videoRefs = result.items;
    });
  }
  
  Future<void> downloadVideo(String videoName) async {
    // Get the reference to the video file in Firebase Storage
    Reference videoRef = FirebaseStorage.instance.ref().child(videoName);

    // Create a temporary file to store the downloaded video
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = '${tempDir.path}/$videoName';
    File tempFile = File(tempPath);

    try {
      // Show a dialog with a circular progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16.0),
                  Text('Downloading video...'),
                ],
              ),
            ),
          );
        },
      );

      // Download the video file to the temporary file
      await videoRef.writeToFile(tempFile);

      // Close the progress dialog
      Navigator.pop(context);

      // Save the video to the gallery
      final result = await GallerySaver.saveVideo(tempPath);
      bool saved = result as bool;

      // Show a snackbar or display a success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved ? 'Video saved to gallery.' : 'Failed to save video to gallery.'),
      ));
    } catch (e) {
      print('Error downloading video: $e');
      // Close the progress dialog
      Navigator.pop(context);

      // Show a snackbar or display an error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to download video.'),
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Storage', style: TextStyle(color: Colors.grey[300],),),
          centerTitle: true,
          backgroundColor: Color.fromRGBO(52, 53, 59, 1),
        ),
        body: Column(
          children: [
            for (var videoRef in videoRefs)
              Card(
                child: ListTile(
                  title: Text(videoRef.name),
                  trailing: IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () => downloadVideo(videoRef.name),
                  ),
                ),
              ),
        ],
        )
      );  
  }
  
}