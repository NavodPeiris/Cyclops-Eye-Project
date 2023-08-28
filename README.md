# Cyclops-Eye-Project
This is the Project done in 2nd Year.

CameraWebServer  -  This is the code that runs on the ESP32 Camera and it will recognize faces while streaming realtime to a Node server running at GCP VM instance. Websockets are used for streaming from ESP32 to server. upload this code to an ESP32.

cloudserver  -  This is the code that is running at Node server. clone this to a folder inside a VM instance running at GCP. You would need to Use GCP Compute Engine to run a VM instance and choose Ubuntu LTS version and install nodejs, git. Also remember to Enable Ingress and Egress through Port 65080 which is the websocket port. run 'npm install' inside cloned directory to install dependencies. run 'sudo node server.js' to run the server.

cyclops  -  This is the Flutter app that is used to view the Camera Feed and can also used for recording video and downloading videos stored in cloud. After cloning run 'pub get' inside cyclops folder to install dependencies. Then build for your android device.

See demonstration: https://drive.google.com/file/d/13jPcI1OmvoVqScENy_Hg5iMIdV4LYF-9/view?usp=sharing
