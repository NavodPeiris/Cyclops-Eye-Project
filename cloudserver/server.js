const path = require('path');
const express = require('express');
const WebSocket = require('ws');
const fs = require('fs');
const { promisify } = require('util');
const writeFileAsync = promisify(fs.writeFile);
const admin = require('firebase-admin');
const { ref, onValue } = require('firebase/database');
const serviceAccount = require('./serviceAccountKey.json'); 
const videoshow = require('videoshow');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cyclops-eye-default-rtdb.asia-southeast1.firebasedatabase.app',
  storageBucket: "cyclops-eye.appspot.com" 
});

for(let i=1; i <= 6000; i++){
    let imagePath = `./img${i}.jpg`;
    if (fs.existsSync(imagePath)) {
        // Delete the file
        fs.unlinkSync(imagePath);
        console.log(`img${i}.jpg deleted successfully.`);
    } else {
        console.log('File does not exist.');
    }
}

const bucket = admin.storage().bucket();

const db = admin.database();

const app = express();
let images = [];
let recStarted = false;

let startTime;
let currentTime;

const WS_PORT  = 65080;
const HTTP_PORT = 80;

var videoOptions = {
    fps: 25,
    loop: 1, // seconds
    transition: false,
    transitionDuration: 0, // seconds
    videoBitrate: 1024,
    videoCodec: 'libx264',
    size: '640x?',
    audioBitrate: '0k',
    audioChannels: 0,
    format: 'mp4',
    pixelFormat: 'yuv420p'
}

let imageCounter = 1; // Track the number of received frames
let videoCounter = 1; // Track the number of videos recorded

let isConverting = false; // Flag to track the conversion process

const wsServer = new WebSocket.Server({port: WS_PORT}, ()=> console.log(`WS Server is listening at ${WS_PORT}`));

let connectedClients = [];
wsServer.on('connection', (ws, req)=>{
    console.log('Connected');
    connectedClients.push(ws);

    const recRef = db.ref('test/rec');

    ws.on('message', data => {

        // Listen for changes to "rec"
        recRef.on('value', async(snapshot) => {
            const rec = snapshot.val();
            
            //if rec is true then record
            if (rec === true) {
                
                if(recStarted === false){
                    startTime = new Date();
                    recStarted = true;
                }

                currentTime = new Date();

                if(startTime !== null){
                    if(((currentTime - startTime)/1000 >= 60) && !isConverting){
                        
                        // Update the value of "rec" to false
                        recRef.set(false)
                            .then(() => {
                            console.log('Value of "rec" updated to false');
                            })
                            .catch((error) => {
                            console.error('Error updating value of "rec":', error);
                            });

                        isConverting = true; // Set the flag to indicate that the conversion is in progress

                        //recording should stop and file should be saved and uploaded to firebase

                        let vidName = `video${videoCounter}.mp4`;
                        console.log("starting conversion...");

                        await new Promise((resolve, reject) => {
                            videoshow(images, videoOptions)
                              .save(vidName)
                              .on('start', function (command) {
                                console.log('ffmpeg process started:', command);
                              })
                              .on('error', function (err, stdout, stderr) {
                                console.error('Error:', err);
                                console.error('ffmpeg stderr:', stderr);
                                reject(err);
                              })
                              .on('end', function (output) {
                                console.log('Video created in:', output);
                                resolve();
                              });
                          });

                        recStarted = false;
                        
                        //deleting all images stored
                        for(let i=1; i <= images.length; i++){
                            let imagePath = `./img${i}.jpg`;
                            if (fs.existsSync(imagePath)) {
                                // Delete the file
                                fs.unlinkSync(imagePath);
                                console.log(`img${i}.jpg deleted successfully.`);
                            } else {
                                console.log('File does not exist.');
                            }
                        }

                        images = [];        //emptying images array
                        
                        //upload to firebase
                        try {
                            await bucket.upload(`./${vidName}`, {
                              destination: vidName
                            });
                        
                            console.log('File uploaded successfully.');
                            // Delete the video file from local storage
                            if (fs.existsSync(vidName)) {
                                fs.unlinkSync(vidName);
                                console.log(`${vidName} deleted from local storage.`);
                            } else {
                                console.log('Video file does not exist in local storage.');
                            }

                        } catch (error) {
                            console.error('Error uploading file:', error);
                        }

                        videoCounter++;
                        isConverting = false;        //converting and uploading is done
                    }
                }

                const fileName = `img${imageCounter}.jpg`; // Generate the file name for the current frame
                imageCounter++;

                try {
                    await writeFileAsync(fileName, data); // Save the received frame as a JPEG file
                    images.push(fileName); // Add the file name to the `images` array
                    console.log(`Saved ${fileName} and added it to the array.`);
                } catch (error) {
                    console.error(`Error saving ${fileName}:`, error);
                }
            }
        });

        connectedClients.forEach((ws,i)=>{
            if(ws.readyState === ws.OPEN){
                ws.send(data);
            }else{
                connectedClients.splice(i ,1);
            }
        })
    });
});

app.get('/client',(req,res)=>res.sendFile(path.resolve(__dirname, './client.html')));
app.listen(HTTP_PORT, ()=> console.log(`HTTP server listening at ${HTTP_PORT}`));