# Code Examples

Complete Arduino sketches for connecting ESP32 to BP Mobile.

## Basic Example

```cpp
#include <WiFi.h>
#include <WebSocketsClient.h>

// WiFi credentials
const char* ssid = "YourNetworkSSID";
const char* password = "YourPassword";

// BP Mobile WebSocket server
const char* serverHost = "192.168.43.1";  // Get from BP Mobile Network Management
const int serverPort = 3000;              // Default port, can be changed

WebSocketsClient webSocket;
String clientName = "ESP32_Sensor_01";
bool isRegistered = false;
unsigned long lastPing = 0;
unsigned long lastDataSend = 0;

void setup() {
  Serial.begin(115200);
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  // Setup WebSocket
  webSocket.begin(serverHost, serverPort, "/");
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);
}

void loop() {
  webSocket.loop();
  
  // Send ping response if needed (handled in webSocketEvent)
  
  // Send data every 100ms (10 Hz)
  if (millis() - lastDataSend > 100 && isRegistered) {
    sendSensorData();
    lastDataSend = millis();
  }
}

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("WebSocket Disconnected");
      isRegistered = false;
      break;
      
    case WStype_CONNECTED:
      Serial.println("WebSocket Connected");
      registerClient();
      break;
      
    case WStype_TEXT:
      handleMessage((char*)payload);
      break;
      
    default:
      break;
  }
}

void registerClient() {
  // Prepare registration message
  String registration = "{"
    "\"type\":\"register\","
    "\"client_name\":\"" + clientName + "\","
    "\"topics\":["
      "\"sensors/temperature\","
      "\"sensors/humidity\""
    "],"
    "\"topic_metadata\":{"
      "\"sensors/temperature\":{"
        "\"description\":\"Temperature reading\","
        "\"unit\":\"°C\","
        "\"sampling_rate\":10.0"
      "},"
      "\"sensors/humidity\":{"
        "\"description\":\"Humidity reading\","
        "\"unit\":\"%\","
        "\"sampling_rate\":10.0"
      "}"
    "}"
  "}";
  
  webSocket.sendTXT(registration);
  Serial.println("Registration sent");
}

void handleMessage(String message) {
  // Parse JSON (simplified - use ArduinoJson library for production)
  if (message.indexOf("\"type\":\"registration_response\"") >= 0) {
    if (message.indexOf("\"status\":\"accepted\"") >= 0) {
      Serial.println("Registration accepted!");
      isRegistered = true;
      
      // Extract system time for synchronization
      // (use ArduinoJson library to parse properly)
    } else {
      Serial.println("Registration rejected!");
      Serial.println(message);
    }
  } else if (message.indexOf("\"type\":\"ping\"") >= 0) {
    // Extract ping_id and respond with pong
    int pingIdStart = message.indexOf("\"ping_id\":\"") + 11;
    int pingIdEnd = message.indexOf("\"", pingIdStart);
    String pingId = message.substring(pingIdStart, pingIdEnd);
    
    String pong = "{"
      "\"type\":\"pong\","
      "\"ping_id\":\"" + pingId + "\","
      "\"timestamp\":" + String(millis()) + ""
    "}";
    
    webSocket.sendTXT(pong);
  }
}

void sendSensorData() {
  // Read sensor values (example)
  float temperature = 25.5; // Replace with actual sensor reading
  float humidity = 60.0;    // Replace with actual sensor reading
  
  unsigned long timestamp = millis(); // Use synchronized time in production
  
  // Send temperature data
  String tempData = "{"
    "\"type\":\"data\","
    "\"topic\":\"sensors/temperature\","
    "\"data\":{"
      "\"value\":" + String(temperature) + ","
      "\"sensor_id\":\"TEMP_001\""
    "},"
    "\"timestamp\":" + String(timestamp) + ""
  "}";
  webSocket.sendTXT(tempData);
  
  // Send humidity data
  String humData = "{"
    "\"type\":\"data\","
    "\"topic\":\"sensors/humidity\","
    "\"data\":{"
      "\"value\":" + String(humidity) + ","
      "\"sensor_id\":\"HUM_001\""
    "},"
    "\"timestamp\":" + String(timestamp) + ""
  "}";
  webSocket.sendTXT(humData);
}
```

## Using ArduinoJson Library (Recommended)

```cpp
#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>

// ... WiFi setup code ...

void registerClient() {
  StaticJsonDocument<512> doc;
  doc["type"] = "register";
  doc["client_name"] = clientName;
  
  JsonArray topics = doc["topics"].to<JsonArray>();
  topics.add("sensors/temperature");
  topics.add("sensors/humidity");
  
  JsonObject metadata = doc["topic_metadata"].to<JsonObject>();
  
  JsonObject tempMeta = metadata["sensors/temperature"].to<JsonObject>();
  tempMeta["description"] = "Temperature reading";
  tempMeta["unit"] = "°C";
  tempMeta["sampling_rate"] = 10.0;
  
  JsonObject humMeta = metadata["sensors/humidity"].to<JsonObject>();
  humMeta["description"] = "Humidity reading";
  humMeta["unit"] = "%";
  humMeta["sampling_rate"] = 10.0;
  
  String registration;
  serializeJson(doc, registration);
  webSocket.sendTXT(registration);
}

void handleMessage(String message) {
  StaticJsonDocument<512> doc;
  deserializeJson(doc, message);
  
  String type = doc["type"];
  
  if (type == "registration_response") {
    String status = doc["status"];
    if (status == "accepted") {
      isRegistered = true;
      // Sync time from server
      if (doc.containsKey("system_time")) {
        unsigned long serverTime = doc["system_time"]["timestamp_ms"];
        // Implement time synchronization
      }
    }
  } else if (type == "ping") {
    String pingId = doc["ping_id"];
    
    StaticJsonDocument<128> pongDoc;
    pongDoc["type"] = "pong";
    pongDoc["ping_id"] = pingId;
    pongDoc["timestamp"] = millis();
    
    String pong;
    serializeJson(pongDoc, pong);
    webSocket.sendTXT(pong);
  }
}

void sendSensorData() {
  float temperature = 25.5;
  float humidity = 60.0;
  
  // Send temperature
  StaticJsonDocument<256> tempDoc;
  tempDoc["type"] = "data";
  tempDoc["topic"] = "sensors/temperature";
  tempDoc["data"]["value"] = temperature;
  tempDoc["data"]["sensor_id"] = "TEMP_001";
  tempDoc["timestamp"] = millis();
  
  String tempMsg;
  serializeJson(tempDoc, tempMsg);
  webSocket.sendTXT(tempMsg);
  
  // Send humidity
  StaticJsonDocument<256> humDoc;
  humDoc["type"] = "data";
  humDoc["topic"] = "sensors/humidity";
  humDoc["data"]["value"] = humidity;
  humDoc["data"]["sensor_id"] = "HUM_001";
  humDoc["timestamp"] = millis();
  
  String humMsg;
  serializeJson(humDoc, humMsg);
  webSocket.sendTXT(humMsg);
}
```

## Required Libraries

Install these libraries in Arduino IDE:

1. **WebSockets** by Markus Sattler
   - Library Manager → Search "WebSockets"
   - Install "WebSockets" by Markus Sattler

2. **ArduinoJson** by Benoit Blanchon (recommended)
   - Library Manager → Search "ArduinoJson"
   - Install "ArduinoJson" by Benoit Blanchon

## Configuration Steps

1. **Update WiFi credentials** in the code
2. **Get server IP and port** from BP Mobile Network Management
3. **Choose unique client name** (avoid duplicates)
4. **Define topics** your ESP32 will publish
5. **Set sampling rates** in topic metadata
6. **Upload and monitor** Serial output for connection status

## Tips

- Use descriptive client names: `ESP32_Sensor_01`, `ESP32_Actuator_02`, etc.
- Organize topics hierarchically: `sensors/temperature`, `actuators/status`
- Respond to ping messages promptly to maintain connection quality
- Use synchronized timestamps from server for accurate data logging
- Implement reconnection logic for network resilience

## Next Steps

- Review [Connection Guide](/docs/connection) for setup
- Check [WebSocket Protocol](/docs/protocol) for message details

