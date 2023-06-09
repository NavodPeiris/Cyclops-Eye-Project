
import 'package:flutter/material.dart';
import 'account.dart';
import 'ImagePicker.dart';
import 'feed.dart';
import 'package:firebase_database/firebase_database.dart';

class Home extends StatefulWidget {

  const Home({super.key});  

  @override
  State<Home> createState() => _HomeState();
  
}

class _HomeState extends State<Home> {
 
  FirebaseDatabase database = FirebaseDatabase.instance;
  DatabaseReference ref = FirebaseDatabase.instance.ref("test"); 
  bool enrolling = false;
  double _currentSliderValue = 45;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Cyclops Eye'),
          centerTitle: true,
          backgroundColor: Color.fromRGBO(143, 148, 251, 1),
          actions: [
            CustomButtonTest(),
          ],
        ),
        body: Column(
          children: <Widget>[
    
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width, // or any desired width
                      child: Feed(),
                    ),
                  ],
                ),
              ),
            ),
            
            Row(
              children: <Widget>[
                /*
                Column(
                  children: <Widget>[
                    Text(
                      "Rotate Camera",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    Slider(
                      value: _currentSliderValue,
                      max: 90,
                      divisions: 2,
                      activeColor: Color.fromRGBO(143, 148, 251, 1),
                      label: _currentSliderValue.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _currentSliderValue = value;
                        });
                      },
                    ),
                
                  ],
                ),
                */
                StreamBuilder<DatabaseEvent>(
                  stream: ref.child('enroll').onValue,
                  builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
                    if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                      dynamic enrollValue = snapshot.data!.snapshot.value;
                      bool enroll = enrollValue as bool;
                      return enroll
                          ? ElevatedButton.icon(
                              onPressed: () async {
                                setState(() {
                                  enrolling = !enrolling;
                                });
                                await ref.update({"enroll": false});
                              },
                              icon: Icon(Icons.stop),
                              label: Text("Stop enrolling"),
                            )
                          : ElevatedButton.icon(
                              onPressed: () async {
                                //enroll images
                                setState(() {
                                  enrolling = !enrolling;
                                });
                                await ref.update({"enroll": true});
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(
                                        Color.fromRGBO(143, 148, 251, 1)),
                              ),
                              icon: Icon(Icons.add_photo_alternate_sharp),
                              label: Text("Enroll faces"),
                            );
                    } else {
                      return CircularProgressIndicator(); // or any loading indicator
                    }
                  },
                ),
                StreamBuilder<DatabaseEvent>(
                  stream: ref.child('online').onValue,     //checking if cam is online
                  builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
                    if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                      dynamic onlineValue = snapshot.data!.snapshot.value;
                      bool online = onlineValue as bool;
                      return online
                          ? IconButton(
                            color: Colors.green,
                            onPressed: (){},
                            icon: Icon(
                            Icons.wifi,
                            size: 24,
                          ))
                          : IconButton(
                            color: Colors.red,
                            onPressed: (){},
                            icon: Icon(
                            Icons.wifi_off,
                            size: 24,
                          ));
                    } else {
                      return CircularProgressIndicator(); // or any loading indicator
                    }
                  },
                ),

              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),

            //ImageUploads(),
          ],
        )
      );  
  }
  
}