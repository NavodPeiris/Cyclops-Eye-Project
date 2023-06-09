import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path/path.dart' as path;
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
 import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:path_provider/path_provider.dart';
import 'videoUtil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:gesture_zoom_box/gesture_zoom_box.dart';
import 'package:intl/intl.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'blinkingTimer.dart';

class Feed extends StatefulWidget {
  final WebSocketChannel channel = IOWebSocketChannel.connect('ws://34.131.251.19:65080');

  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> {

  FirebaseDatabase database = FirebaseDatabase.instance;
  DatabaseReference ref = FirebaseDatabase.instance.ref("test");

  bool timerTriggered = false;
  late DateTime startTime;
  late DateTime currentTime;
  late int timeDifferenceInSeconds;
  bool touchStopped = false;

  final double videoWidth = 640;
  final double videoHeight = 480;

  double newVideoSizeWidth = 640;
  double newVideoSizeHeight = 480;

  late bool isLandscape;
  late String _timeString;

  var _globalKey = new GlobalKey();

  late Timer _timer;
  late bool isRecording;

  late int frameNum;
  late ProgressDialog pd;

  VideoUtil videoUtil = new VideoUtil();

  @override
  void initState() {
    super.initState();
    isLandscape = false;
    isRecording = false;

    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) => _getTime());

    frameNum = 0;
    
    videoUtil.workPath = 'images';
    videoUtil.getAppTempDirectory();

    pd = ProgressDialog(context: context);
    
  }

  @override
  void dispose() {
    widget.channel.sink.close();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(builder: (context, orientation) {
        var screenWidth = MediaQuery.of(context).size.width;
        var screenHeight = MediaQuery.of(context).size.height;

        if (orientation == Orientation.portrait) {
          //screenWidth < screenHeight

          isLandscape = false;
          newVideoSizeWidth = screenWidth;
          newVideoSizeHeight = videoHeight * newVideoSizeWidth / videoWidth;
        } else {
          isLandscape = true;
          newVideoSizeHeight = screenHeight;
          newVideoSizeWidth = videoWidth * newVideoSizeHeight / videoHeight;
        }

        return Container(
          color: Colors.black,
          child: StreamBuilder(
            stream: widget.channel.stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              } else {
                if (isRecording) {
                  videoUtil.saveImageFileToDirectory(
                      snapshot.data, 'image_$frameNum.jpg');
                  frameNum++;
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        SizedBox(
                          height: isLandscape ? 0 : 30,
                        ),
                        Stack(
                          children: <Widget>[
                            RepaintBoundary(
                              key: _globalKey,
                              child: GestureZoomBox(
                                maxScale: 5.0,
                                doubleTapScale: 2.0,
                                duration: Duration(milliseconds: 200),
                                child: Image.memory(
                                  snapshot.data,
                                  gaplessPlayback: true,
                                  width: newVideoSizeWidth,
                                  height: newVideoSizeHeight,
                                ),
                              ),
                            ),
                            Positioned.fill(
                                child: Align(
                              child: Column(
                                children: <Widget>[
                                  SizedBox(
                                    height: 16,
                                  ),
                                  Text(
                                    'ESP32\'s cam',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w300),
                                  ),
                                  SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    'Live | $_timeString',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w300),
                                  ),
                                  SizedBox(
                                    height: 16,
                                  ),
                                  isRecording ? BlinkingTimer() : Container(),
                                ],
                              ),
                              alignment: Alignment.topCenter,
                            ))
                          ],
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.black,
                            width: MediaQuery.of(context).size.width,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  
                                  StreamBuilder<DatabaseEvent>(
                                    stream: ref.child('rec').onValue,
                                    builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
                                      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                                        dynamic recValue = snapshot.data!.snapshot.value;
                                        bool rec = recValue as bool;
                                        if(rec){
                                          if(isRecording){
                                            currentTime = DateTime.now();
                                            timeDifferenceInSeconds = getTimeDifferenceInSeconds(startTime, currentTime);
                                            print('elapsed seconds : $timeDifferenceInSeconds');
                                            if(timerTriggered){
                                              if(timeDifferenceInSeconds >= 60){
                                                videoRecording();
                                                print('video ending : $currentTime');
                                                timerTriggered = false;
                                                //make rec false
                                                updateRec();
                                              }
                                            }
                                            else{
                                              updateRec();
                                            }
                                          }
                                          else{
                                            if(timerTriggered){
                                              //make rec false
                                              timerTriggered = false;
                                              updateRec();
                                            }
                                            else{
                                            
                                              videoRecording();
                                              timerTriggered = true;
                                              startTime = DateTime.now();
                                              print('video starting : $startTime');
                                            }
                                              
                                          }
                                        }

                                        return IconButton(
                                                color: Colors.white,
                                                icon: Icon(
                                                  isRecording ? Icons.stop : Icons.videocam,
                                                  size: 24,
                                                ),
                                                onPressed: (){
                                                  
                                                  videoRecording();
                                                },
                                              );
                                        
                                      } else {
                                        return CircularProgressIndicator(); // or any loading indicator
                                      }
                                    },
                                  ),
                                  IconButton(
                                    color: Colors.white,
                                    icon: Icon(
                                      Icons.photo_camera,
                                      size: 24,
                                    ),
                                    onPressed: takeScreenShot,
                                  ),
                                  IconButton(
                                    color: Colors.white,
                                    onPressed: (){},
                                      icon: Icon(
                                    Icons.mic,
                                    size: 24,
                                  )),
                                  IconButton(
                                    color: Colors.white,
                                    onPressed: (){
                                      Navigator.pushNamed(context, '/storage');
                                    },
                                      icon: Icon(
                                    Icons.storage,
                                    size: 24,
                                  )),
                                  IconButton(
                                    color: Colors.white,
                                    onPressed: (){},
                                      icon: Icon(
                                    Icons.add_alert,
                                    size: 24,
                                  ))
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        );
      }),
      floatingActionButton: _getFab(),
    );
  }

  updateRec() async {
    await ref.update({"rec": false});
  }

  int getTimeDifferenceInSeconds(DateTime startTime, DateTime endTime) {
    Duration difference = endTime.difference(startTime);
    return difference.inSeconds;
  } 

  int getCurrentTimeInSeconds() {
    DateTime now = DateTime.now();
    return now.second;
  }

  Future<String> _getApplicationDocumentsDirectory() async {
    final directory = await getExternalStorageDirectory();
    return directory!.path;
  }


  takeScreenShot() async {
    RenderRepaintBoundary? boundary =
        _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    var image = await boundary?.toImage();
    var byteData = await image?.toByteData(format: ImageByteFormat.png);
    final Uint8List? pngBytes = byteData?.buffer.asUint8List();
    
    //create file
    final String dir = (await getApplicationDocumentsDirectory()).path;
    final String fullPath = '$dir/${DateTime.now().millisecond}.png';
    File capturedFile = File(fullPath);
    await capturedFile.writeAsBytes(pngBytes as List<int>);
    print(capturedFile.path);

    bool? res = await GallerySaver.saveImage(capturedFile.path);

    if(res != null){
      Fluttertoast.showToast(
        msg: res ? "ScreenShot Saved" : "ScreenShot Failure!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
    }
    
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MM/dd hh:mm:ss aaa').format(dateTime);
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = _formatDateTime(now);
    });
  }

  Widget _getFab() {
    return SpeedDial(
      overlayOpacity: 0.1,
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: IconThemeData(size: 22),
      visible: isLandscape,
      curve: Curves.bounceIn,
      children: [
        SpeedDialChild(
          child: Icon(Icons.photo_camera),
          onTap: takeScreenShot,
        ),
        SpeedDialChild(
            child: isRecording ? Icon(Icons.stop) : Icon(Icons.videocam),
            onTap: videoRecording)
      ],
    );
  }

  videoRecording() {
    isRecording = !isRecording;

    if (!isRecording && frameNum > 0) {
      frameNum = 0;
      makeVideoWithFFMpeg();
    }
  }

  makeVideoWithFFMpeg() {
    /*pd.show(
       msg: 'Saving video ...',
       borderRadius: 10,
       backgroundColor: Colors.black,
       elevation: 10,
       msgColor: Colors.white70,
       msgFontSize: 17,
       msgFontWeight: FontWeight.w300,
    );*/
    
    String tempVideofileName = "${DateTime.now().millisecondsSinceEpoch}.mp4";
    FFmpegKit.execute(videoUtil.generateEncodeVideoScript("mpeg4", tempVideofileName))
        .then((session) async{
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            // SUCCESS
            //pd.close();
      
            print("Video complete");

            String outputPath = videoUtil.appTempDir + "/$tempVideofileName";
            _saveVideo(outputPath);
          }
    });
  }

  _saveVideo(String path) async {
    GallerySaver.saveVideo(path).then((result) {
      print("Video Save result : $result");

      if(result != null){
        Fluttertoast.showToast(
          msg: result ? "Video Saved" : "Video Failure!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
      }
      
      videoUtil.deleteTempDirectory();
    });
  }
}