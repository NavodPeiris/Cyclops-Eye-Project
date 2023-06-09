import 'dart:io';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path/path.dart';

class ImageUploads extends StatefulWidget {
  ImageUploads({Key? key}) : super(key: key);

  @override
  _ImageUploadsState createState() => _ImageUploadsState();
}

class _ImageUploadsState extends State<ImageUploads> {

  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;

  File? _photo;
  final ImagePicker _picker = ImagePicker();
  var nameOfPerson;
  final TextEditingController nameController = TextEditingController();

  Future imgFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _photo = File(pickedFile.path);
        uploadFile();
      } else {
        print('No image selected.');
      }
    });
  }

  Future imgFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    setState(() {
      if (pickedFile != null) {
        _photo = File(pickedFile.path);
        uploadFile();
      } else {
        print('No image selected.');
      }
    });
  }

  Future uploadFile() async {
    if (_photo == null) return;
    final fileName = nameOfPerson;
    final destination = 'images/';

    try {
      final ref = firebase_storage.FirebaseStorage.instance
          .ref(destination)
          .child(fileName);
      await ref.putFile(_photo!);
    } catch (e) {
      print('error occured');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
       onPressed: () {
         _openPopup(context);
       },
       style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all<Color>(Color.fromRGBO(143, 148, 251, 1)),
       ),
       icon: Icon(Icons.photo_rounded),
       label: Text("Upload Photo"),
     );
  }

  _openPopup(context) {
   Alert(
       context: context,
       title: "Person Details",
       content: Column(
         children: <Widget>[
           TextField(
             controller: nameController,
             decoration: InputDecoration(
               icon: Icon(Icons.account_circle),
               labelText: 'Name',
             ),
           ),
         ],
       ),
       buttons: [
         DialogButton(
           onPressed: () => {
              setState(() {
                nameOfPerson = nameController.text;
              }),
              Navigator.pop(context),
              _showPicker(context)
            },
           child: Text(
             "Enter",
             style: TextStyle(color: Colors.white, fontSize: 20),
           ),
         )
       ]).show();
 }

  void _showPicker(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Container(
              child: new Wrap(
                children: <Widget>[
                  new ListTile(
                      leading: new Icon(Icons.photo_library),
                      title: new Text('Gallery'),
                      onTap: () {

                        imgFromGallery();
                        Navigator.of(context).pop();
                      }),
                  new ListTile(
                    leading: new Icon(Icons.photo_camera),
                    title: new Text('Camera'),
                    onTap: () {
                      imgFromCamera();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }
}