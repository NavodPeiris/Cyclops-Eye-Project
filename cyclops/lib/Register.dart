import 'package:flutter/material.dart';
import 'Animation/FadeAnimation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth.dart';

class Register extends StatefulWidget {
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {

  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  String? errorMessage = "";

  final TextEditingController deviceIdController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _showMyDialog() async {
   return showDialog<void>(
     context: context,
     barrierDismissible: false, // user must tap button!
     builder: (BuildContext context) {
       return AlertDialog(
         title: const Text('Form is incomplete'),
         content: SingleChildScrollView(
           child: ListBody(
             children: const <Widget>[
               Text('Username or password is not filled'),
               Text('Please fill all required fields'),
             ],
           ),
         ),
         actions: <Widget>[
           TextButton(
             child: const Text('Ok'),
             onPressed: () {
               Navigator.of(context).pop();
             },
           ),
         ],
       );
     },
   );
  }

  Future<void> createUserWithEmailAndPassword() async {
    try {
      await Auth().createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
    }
    on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
      	child: Container(
	        child: Column(
	          children: <Widget>[
	            Container(
	              height: 400,
	              decoration: BoxDecoration(
	                image: DecorationImage(
	                  image: AssetImage('assets/images/background.png'),
	                  fit: BoxFit.fill
	                )
	              ),
	              child: Stack(
	                children: <Widget>[
	                  Positioned(
	                    left: 30,
	                    width: 80,
	                    height: 200,
	                    child: FadeAnimation(1, Container(
	                      decoration: BoxDecoration(
	                        image: DecorationImage(
	                          image: AssetImage('assets/images/light-1.png')
	                        )
	                      ),
	                    )),
	                  ),
	                  Positioned(
	                    left: 140,
	                    width: 80,
	                    height: 150,
	                    child: FadeAnimation(1.3, Container(
	                      decoration: BoxDecoration(
	                        image: DecorationImage(
	                          image: AssetImage('assets/images/light-2.png')
	                        )
	                      ),
	                    )),
	                  ),
	                  Positioned(
	                    right: 40,
	                    top: 40,
	                    width: 80,
	                    height: 150,
	                    child: FadeAnimation(1.5, Container(
	                      decoration: BoxDecoration(
	                        image: DecorationImage(
	                          image: AssetImage('assets/images/clock.png')
	                        )
	                      ),
	                    )),
	                  ),
	                  Positioned(
	                    child: FadeAnimation(1.6, Container(
	                      margin: EdgeInsets.only(top: 50),
	                      child: Center(
	                        child: Text("Sign Up", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),),
	                      ),
	                    )),
	                  )
	                ],
	              ),
	            ),
	            Padding(
	              padding: EdgeInsets.all(30.0),
	              child: Column(
	                children: <Widget>[
	                  FadeAnimation(1.8, Container(
	                    padding: EdgeInsets.all(5),
	                    decoration: BoxDecoration(
	                      color: Colors.white,
	                      borderRadius: BorderRadius.circular(10),
	                      boxShadow: [
	                        BoxShadow(
	                          color: Color.fromRGBO(143, 148, 251, .2),
	                          blurRadius: 20.0,
	                          offset: Offset(0, 10)
	                        )
	                      ]
	                    ),
	                    child: Column(
	                      children: <Widget>[
                          Container(
	                          padding: EdgeInsets.all(8.0),
	                          decoration: BoxDecoration(
	                            border: Border(bottom: BorderSide(color: Colors.deepPurple))
	                          ),
	                          child: TextField(
                              controller: deviceIdController,
	                            decoration: InputDecoration(
	                              border: InputBorder.none,
	                              hintText: "Device ID",
	                              hintStyle: TextStyle(color: Colors.grey[400])
	                            ),
	                          ),
	                        ),
                          Container(
	                          padding: EdgeInsets.all(8.0),
	                          decoration: BoxDecoration(
	                            border: Border(bottom: BorderSide(color: Colors.deepPurple))
	                          ),
	                          child: TextField(
                              controller: userNameController,
	                            decoration: InputDecoration(
	                              border: InputBorder.none,
	                              hintText: "Username",
	                              hintStyle: TextStyle(color: Colors.grey[400])
	                            ),
	                          ),
	                        ),
	                        Container(
	                          padding: EdgeInsets.all(8.0),
	                          decoration: BoxDecoration(
	                            border: Border(bottom: BorderSide(color: Colors.deepPurple))
	                          ),
	                          child: TextField(
                              controller: emailController,
	                            decoration: InputDecoration(
	                              border: InputBorder.none,
	                              hintText: "Email",
	                              hintStyle: TextStyle(color: Colors.grey[400])
	                            ),
	                          ),
	                        ),
	                        Container(
	                          padding: EdgeInsets.all(8.0),
	                          child: TextField(
                              controller: passwordController,
	                            decoration: InputDecoration(
	                              border: InputBorder.none,
	                              hintText: "Password",
	                              hintStyle: TextStyle(color: Colors.grey[400])
	                            ),
	                          ),
	                        )
	                      ],
	                    ),
	                  )),
	                  SizedBox(height: 30,),
	                  FadeAnimation(2, 
                      GestureDetector(
                          onTap: () async {
                            if(deviceIdController.text != "" && userNameController.text != "" && emailController.text != "" && passwordController.text != ""){
                              await users.doc(deviceIdController.text).set(
                                {
                                  "device Id": deviceIdController.text,
                                  "name": userNameController.text,
                                  "email": emailController.text,
                                  "password": passwordController.text
                                }
                              );
                              createUserWithEmailAndPassword();
                              Navigator.pushNamed(context, '/');
                            }
                            else {
                              _showMyDialog();
                            }  
                          },
                          child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromRGBO(143, 148, 251, 1),
                                Color.fromRGBO(143, 148, 251, .6),
                              ]
                            )
                          ),
                          child: Center(               
                            child: Text("Sign Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      )
                    ),
	                  SizedBox(height: 70,),   
	                ],
	              ),
	            )
	          ],
	        ),
	      ),
      )
    );
  }
}