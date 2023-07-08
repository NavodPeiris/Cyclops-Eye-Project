#include "esp_camera.h"
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include <ArduinoWebsockets.h>
#include "img_converters.h"     
#include "fb_gfx.h"             
#include "fd_forward.h"          
#include "fr_forward.h"             
#include "esp_timer.h"
#include <WiFiManager.h>

#define ENROLL_CONFIRM_TIMES 5
#define FACE_ID_SAVE_NUMBER 7

// Arduino like analogWrite
// value has to be between 0 and valueMax
void ledcAnalogWrite(uint8_t channel, uint32_t value, uint32_t valueMax = 180)
{
  // calculate duty, 8191 from 2 ^ 13 - 1
  uint32_t duty = (8191 / valueMax) * min(value, valueMax);
  ledcWrite(channel, duty);
}
int pan_center = 90; // center the pan servo
int tilt_center = 90; // center the tilt servo
 
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define LED_GPIO_NUM      33
 
#define FACE_COLOR_RED    0x000000FF
#define FACE_COLOR_GREEN  0x0000FF00
#define FACE_COLOR_BLUE   0x00FF0000
#define FACE_COLOR_YELLOW (FACE_COLOR_RED | FACE_COLOR_GREEN)
#define FACE_COLOR_CYAN   (FACE_COLOR_BLUE | FACE_COLOR_GREEN)

static int8_t detection_enabled = 1;     
static int8_t recognition_enabled = 1;   
static int8_t is_enrolling = 1;
static face_id_list id_list = {0};
static int8_t flash_value = 0;
int8_t enroll_id = 0;

box_array_t *net_boxes = NULL;

static inline mtmn_config_t app_mtmn_config()
{
  mtmn_config_t mtmn_config = {0};
  mtmn_config.type = FAST;
  mtmn_config.min_face = 80;
  mtmn_config.pyramid = 0.707;
  mtmn_config.pyramid_times = 4;
  mtmn_config.p_threshold.score = 0.6;
  mtmn_config.p_threshold.nms = 0.7;
  mtmn_config.p_threshold.candidate_number = 20;
  mtmn_config.r_threshold.score = 0.7;
  mtmn_config.r_threshold.nms = 0.7;
  mtmn_config.r_threshold.candidate_number = 10;
  mtmn_config.o_threshold.score = 0.7;
  mtmn_config.o_threshold.nms = 0.7;
  mtmn_config.o_threshold.candidate_number = 1;
  return mtmn_config;
}
mtmn_config_t mtmn_config = app_mtmn_config();


#define API_KEY "YOUR API KEY"
#define DATABASE_URL "https://{YOUR PROJECT NAME}-default-rtdb.asia-southeast1.firebasedatabase.app" 

FirebaseData fbdo;

FirebaseAuth auth;
FirebaseConfig firebaseConfig;

bool signupOK = false;
bool enroll = false;
bool rec = false;
bool is_recording = false;

const char* websocket_server_host = "34.100.134.218";     //ip address of server
const uint16_t websocket_server_port = 65080;            //65080 is the port for websockets

using namespace websockets;
WebsocketsClient client;

void startCameraServer();

void setup() {

  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); //disable brownout detector

  WiFi.mode(WIFI_STA); // explicitly set mode, esp defaults to STA+AP
  
  Serial.begin(115200);
  Serial.println();

  WiFiManager wm;

  wm.resetSettings();         //if resetting, again and again have to give credentials
  
  bool res;

  res = wm.autoConnect("Cyclops Eye","password123"); // password protected ap

  if(!res) {
    Serial.println("Failed to connect");
    // ESP.restart();
  } 
  else {
    //if you get here you have connected to the WiFi    
    Serial.println("connected...yeey :)");
    
  }

  // Ai-Thinker: pins 2 and 12
  ledcSetup(2, 50, 16); //channel, freq, resolution
  ledcAttachPin(2, 2); // pin, channel
 
  ledcSetup(4, 50, 16);
  ledcAttachPin(12, 4);
 
  ledcAnalogWrite(2, 90); // channel, 0-180
  delay(1000);
  ledcAnalogWrite(4, 90);
 
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  //init with high specs to pre-allocate larger buffers
  if (psramFound()) {
    config.frame_size = FRAMESIZE_UXGA;
    config.jpeg_quality = 10;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }
#if defined(CAMERA_MODEL_ESP_EYE)
  pinMode(13, INPUT_PULLUP);
  pinMode(14, INPUT_PULLUP);
#endif
  // camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }
 
  sensor_t * s = esp_camera_sensor_get();
  s->set_brightness(s, 1); // up the brightness just a bit
  s->set_framesize(s, FRAMESIZE_QVGA);
  

  face_id_init(&id_list, FACE_ID_SAVE_NUMBER, ENROLL_CONFIRM_TIMES); 
 
  while(!client.connect(websocket_server_host, websocket_server_port, "/")){
    delay(500);
    Serial.print(".");
  }
  Serial.println("Websocket Connected!");          

  
  firebaseConfig.api_key = API_KEY;
  firebaseConfig.database_url = DATABASE_URL;
  if (Firebase.signUp(&firebaseConfig, &auth, "", "")) {
    Serial.println("ok");
    signupOK = true;
  }
  else {
    Serial.printf("%s\n", firebaseConfig.signer.signupError.message.c_str());
  }

  Firebase.begin(&firebaseConfig, &auth);

  Firebase.RTDB.setBool(&fbdo, "/test/online", true);          //indicating camera is online
  
  startCameraServer();
  
}

void loop() {
   
}

static void rgb_print(dl_matrix3du_t *image_matrix, uint32_t color, const char * str){
    fb_data_t fb;
    fb.width = image_matrix->w;
    fb.height = image_matrix->h;
    fb.data = image_matrix->item;
    fb.bytes_per_pixel = 3;
    fb.format = FB_BGR888;
    fb_gfx_print(&fb, (fb.width - (strlen(str) * 14)) / 2, 10, color, str);
}


static int rgb_printf(dl_matrix3du_t *image_matrix, uint32_t color, const char *format, ...){
    char loc_buf[64];
    char * temp = loc_buf;
    int len;
    va_list arg;
    va_list copy;
    va_start(arg, format);
    va_copy(copy, arg);
    len = vsnprintf(loc_buf, sizeof(loc_buf), format, arg);
    va_end(copy);
    if(len >= sizeof(loc_buf)){
        temp = (char*)malloc(len+1);
        if(temp == NULL) {
            return 0;
        }
    }
    vsnprintf(temp, len+1, format, arg);
    va_end(arg);
    rgb_print(image_matrix, color, temp);
    if(len > 64){
        free(temp);
    }
    return len;
}

void face_track(box_array_t *boxes)
{
  int x, y, w, h, i, half_width, half_height;

  for (i = 0; i < boxes->len; i++) {
 
    // Convoluted way of finding face centre...
    x = ((int)boxes->box[i].box_p[0]);
    w = (int)boxes->box[i].box_p[2] - x + 1;
    half_width = w / 2;
    int face_center_pan = x + half_width; // image frame face centre x co-ordinate
 
    y = (int)boxes->box[i].box_p[1];
    h = (int)boxes->box[i].box_p[3] - y + 1;
    half_height = h / 2;
    int face_center_tilt = y + half_height;  // image frame face centre y co-ordinate
 
    //    assume QVGA 320x240
    //    int sensor_width = 320;
    //    int sensor_height = 240;
    //    int lens_fov = 45
    //    float diagonal = sqrt(sq(sensor_width) + sq(sensor_height)); // pixels along the diagonal
    //    float pixels_per_degree = diagonal / lens_fov;
    //    400/45 = 8.89
 
    float move_to_x = pan_center + ((160 - face_center_pan) / 8.89) ;
    float move_to_y = tilt_center + ((-120 + face_center_tilt) / 8.89) ;
 
    pan_center = (pan_center + move_to_x) / 2;
    Serial.println(pan_center);
    ledcAnalogWrite(2, pan_center); // channel, 0-180
 
    tilt_center = (tilt_center + move_to_y) / 2;
    int reversed_tilt_center = map(tilt_center, 0, 180, 180, 0);
    ledcAnalogWrite(4, reversed_tilt_center); // channel, 0-180
  }
}


static void draw_face_boxes(dl_matrix3du_t *image_matrix, box_array_t *boxes, int face_id)
{
  int x, y, w, h, i;
  uint32_t color = FACE_COLOR_YELLOW;
  if(face_id < 0){
      color = FACE_COLOR_RED;
  } else if(face_id > 0){
      color = FACE_COLOR_GREEN;
  }
  fb_data_t fb;
  fb.width = image_matrix->w;
  fb.height = image_matrix->h;
  fb.data = image_matrix->item;
  fb.bytes_per_pixel = 3;
  fb.format = FB_BGR888;
  for (i = 0; i < boxes->len; i++) {
    x = (int)boxes->box[i].box_p[0];
    y = (int)boxes->box[i].box_p[1];
    w = (int)boxes->box[i].box_p[2] - x + 1;
    h = (int)boxes->box[i].box_p[3] - y + 1;
    fb_gfx_drawFastHLine(&fb, x, y, w, color);
    fb_gfx_drawFastHLine(&fb, x, y+h-1, w, color);
    fb_gfx_drawFastVLine(&fb, x, y, h, color);
    fb_gfx_drawFastVLine(&fb, x+w-1, y, h, color);
  }
}

static int run_face_recognition(dl_matrix3du_t *image_matrix, box_array_t *net_boxes){
    dl_matrix3du_t *aligned_face = NULL;
    int matched_id = 0;

    aligned_face = dl_matrix3du_alloc(1, FACE_WIDTH, FACE_HEIGHT, 3);
    if(!aligned_face){
        Serial.println("Could not allocate face recognition buffer");
        return matched_id;
    }
    if (align_face(net_boxes, image_matrix, aligned_face) == ESP_OK){
        if (is_enrolling == 1){  
            int8_t left_sample_face = enroll_face(&id_list, aligned_face);

            if(left_sample_face == (ENROLL_CONFIRM_TIMES - 1)){
                enroll_id = id_list.tail;
                Serial.printf("Enrolling Face ID: %d\n", enroll_id);
            }
            Serial.printf("Enrolling Face ID: %d sample %d\n", enroll_id, ENROLL_CONFIRM_TIMES - left_sample_face);
            rgb_printf(image_matrix, FACE_COLOR_CYAN, "ID[%u] Sample[%u]", id_list.tail, ENROLL_CONFIRM_TIMES - left_sample_face);
            if (left_sample_face == 0){
                is_enrolling = 0;
                Firebase.RTDB.setBool(&fbdo, "/test/enroll", false);
                enroll_id = id_list.tail;
                
            }
        } else {  
            matched_id = recognize_face(&id_list, aligned_face);
            if (matched_id >= 0) {  
                Serial.printf("Match Face ID: %u\n", matched_id);
       
            } else {  
                Serial.printf("No Match Found");
                rgb_print(image_matrix, FACE_COLOR_RED, "Intruder Alert!");
                matched_id = -1;
                
                /*
                unsigned long currentTime = millis();
                if (currentTime - lastPrintTime >= printInterval) {
                  sendMessage();
                  lastPrintTime = currentTime;
                }
                */
                
                if (Firebase.ready() && signupOK ) {
                  if (Firebase.RTDB.getBool(&fbdo, "/test/rec", &rec)) {
                    if(!is_recording){
                      
                        is_recording = true;
                        Firebase.RTDB.setBool(&fbdo, "/test/rec", true);
                      
                    }
                    else{
                      if(rec == false){
                        is_recording = false;
                      }
                    }
                  }
                  else {
                    Serial.printf(fbdo.errorReason().c_str());
                  }
                } 
                
            }
        }
    } else {  
        Serial.println("Face Not Aligned");
        rgb_print(image_matrix, FACE_COLOR_YELLOW, "Human Detected");
    }
    Serial.println();
    
    dl_matrix3du_free(aligned_face);
    return matched_id;
}


void startCameraServer(){
  
    camera_fb_t * fb = NULL;
    size_t _jpg_buf_len = 0;
    uint8_t * _jpg_buf = NULL;
    char * part_buf[64];
    dl_matrix3du_t *image_matrix = NULL;
    bool detected = false;
    int face_id = 0;
    int64_t fr_start = 0;
    int64_t fr_ready = 0;
    int64_t fr_face = 0;
    int64_t fr_recognize = 0;
    int64_t fr_encode = 0;

    static int64_t last_frame = 0;
    if(!last_frame) {
        last_frame = esp_timer_get_time();
    }

    while(true){
        
        if (Firebase.ready() && signupOK ) {
          if (Firebase.RTDB.getBool(&fbdo, "/test/enroll", &enroll)) {
            if(enroll){
              is_enrolling = 1;
            }
            else{
              is_enrolling = 0;
            }
          }
          else {
            Serial.printf(fbdo.errorReason().c_str());
          }
        } 
        
        detected = false;
        face_id = 0;
        fb = esp_camera_fb_get();
        if (!fb) {
            Serial.println("Camera capture failed");
            
        } else {
            fr_start = esp_timer_get_time();
            fr_ready = fr_start;
            fr_face = fr_start;
            fr_encode = fr_start;
            fr_recognize = fr_start;
            if(!detection_enabled){
                if(fb->format != PIXFORMAT_JPEG){
                    bool jpeg_converted = frame2jpg(fb, 80, &_jpg_buf, &_jpg_buf_len);
                    esp_camera_fb_return(fb);
                    fb = NULL;
                    if(!jpeg_converted){
                        Serial.println("JPEG compression failed");
                       
                    }
                } else {
                    _jpg_buf_len = fb->len;
                    _jpg_buf = fb->buf;
                }
            } else {

                image_matrix = dl_matrix3du_alloc(1, fb->width, fb->height, 3);

                if (!image_matrix) {
                    Serial.println("dl_matrix3du_alloc failed");
                    
                } else {
                    if(!fmt2rgb888(fb->buf, fb->len, fb->format, image_matrix->item)){
                        Serial.println("fmt2rgb888 failed");
                        
                    } else {
                        fr_ready = esp_timer_get_time();
                        box_array_t *net_boxes = NULL;
                        if(detection_enabled){
                            net_boxes = face_detect(image_matrix, &mtmn_config);  
                        }
                        fr_face = esp_timer_get_time();
                        fr_recognize = fr_face;
                        if (net_boxes || fb->format != PIXFORMAT_JPEG){
                            if(net_boxes){
                                //Serial.println("faces = " + String(net_boxes->len)); 
                                detected = true;
                                face_track(net_boxes);
                                if(recognition_enabled){
                                    face_id = run_face_recognition(image_matrix, net_boxes);  
                                }
                                fr_recognize = esp_timer_get_time();
                                draw_face_boxes(image_matrix, net_boxes, face_id);  
                                dl_lib_free(net_boxes->score);
                                dl_lib_free(net_boxes->box);
                                dl_lib_free(net_boxes->landmark);
                                dl_lib_free(net_boxes);                                
                                net_boxes = NULL;
                            }
                            if(!fmt2jpg(image_matrix->item, fb->width*fb->height*3, fb->width, fb->height, PIXFORMAT_RGB888, 90, &_jpg_buf, &_jpg_buf_len)){
                                Serial.println("fmt2jpg failed");
                                
                            }
                            esp_camera_fb_return(fb);
                            fb = NULL;
                        } else {
                            _jpg_buf = fb->buf;
                            _jpg_buf_len = fb->len;
                        }
                        fr_encode = esp_timer_get_time();
                    }
                    dl_matrix3du_free(image_matrix);
                }
            }
        }

        client.sendBinary((const char *)_jpg_buf, _jpg_buf_len);
        
        if(fb){
            esp_camera_fb_return(fb);
            fb = NULL;
            _jpg_buf = NULL;
        } else if(_jpg_buf){
            free(_jpg_buf);
            _jpg_buf = NULL;
        }
        
    }

}
