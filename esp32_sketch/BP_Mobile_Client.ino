/*
 * BP Mobile ESP32 Client
 * 
 * This sketch connects an ESP32 to the BP Mobile app via WebSocket
 * and publishes sensor data following the BP Mobile protocol.
 * 
 * Required Libraries:
 * - WebSockets by Markus Sattler
 * - ArduinoJson by Benoit Blanchon (recommended)
 * 
 * Configuration:
 * 1. Update WiFi credentials below
 * 2. Get server IP and port from BP Mobile Network Management
 * 3. Choose a unique client name
 * 4. Define your topics and metadata
 */

#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>

// ============================================================================
// CONFIGURATION - Update these values
// ============================================================================

// WiFi credentials
const char* ssid = "Galaxy A13A2C8";        // Change to your WiFi/hotspot SSID
const char* password = "@@@@@@@@";        // Change to your WiFi/hotspot password

// BP Mobile WebSocket server
const char* serverHost = "10.188.182.160";     // Get from BP Mobile Network Management
const int serverPort = 3000;       

// Client identification
const char* clientName = "ESP32_Sensor_01";   // Must be unique! Change if you have multiple devices

// Sensor configuration
const float TEMP_SAMPLING_RATE = 10.0;        // Hz (10 samples per second)
const float HUMIDITY_SAMPLING_RATE = 5.0;    // Hz (5 samples per second)

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

WebSocketsClient webSocket;
bool isRegistered = false;
bool isConnected = false;

// Timing
unsigned long lastPingReceived = 0;
unsigned long lastDataSend = 0;
unsigned long lastTempSend = 0;
unsigned long lastHumiditySend = 0;
unsigned long long serverTimeOffset = 0;  // Offset: serverUnixTime - clientBootTime (64-bit for Unix timestamps)
unsigned long bootTimeMillis = 0;         // millis() value at registration time (32-bit is fine)
unsigned long connectionStartTime = 0;

// Sensor values (replace with actual sensor readings)
float temperature = 25.5;
float humidity = 60.0;

// ============================================================================
// SETUP
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== BP Mobile ESP32 Client ===");
  Serial.print("Client Name: ");
  Serial.println(clientName);
  
  // Connect to WiFi
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi connection failed!");
    Serial.println("Please check your SSID and password.");
    return;
  }
  
  Serial.println();
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  Serial.print("Signal strength (RSSI): ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");
  
  // Setup WebSocket
  webSocket.begin(serverHost, serverPort, "/");
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);
  
  Serial.print("Connecting to WebSocket server: ws://");
  Serial.print(serverHost);
  Serial.print(":");
  Serial.println(serverPort);
  
  connectionStartTime = millis();
}

// ============================================================================
// MAIN LOOP
// ============================================================================

void loop() {
  webSocket.loop();
  
  // Only send data if registered
  if (isRegistered && isConnected) {
    unsigned long now = millis();
    
    // Send temperature data at configured rate
    if (now - lastTempSend >= (1000.0 / TEMP_SAMPLING_RATE)) {
      sendTemperatureData();
      lastTempSend = now;
    }
    
    // Send humidity data at configured rate
    if (now - lastHumiditySend >= (1000.0 / HUMIDITY_SAMPLING_RATE)) {
      sendHumidityData();
      lastHumiditySend = now;
    }
  }
  
  // Read sensors (replace with actual sensor reading code)
  // For demo purposes, we'll simulate sensor readings
  temperature = 20.0 + (sin(millis() / 10000.0) * 5.0);
  humidity = 50.0 + (cos(millis() / 8000.0) * 10.0);
  
  delay(10); // Small delay to prevent watchdog issues
}

// ============================================================================
// WEBSOCKET EVENT HANDLER
// ============================================================================

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("WebSocket Disconnected");
      isConnected = false;
      isRegistered = false;
      break;
      
    case WStype_CONNECTED:
      Serial.println("WebSocket Connected");
      isConnected = true;
      // Register immediately after connection
      registerClient();
      break;
      
    case WStype_TEXT:
      handleMessage((char*)payload);
      break;
      
    case WStype_ERROR:
      Serial.print("WebSocket Error: ");
      Serial.println((char*)payload);
      break;
      
    default:
      break;
  }
}

// ============================================================================
// CLIENT REGISTRATION
// ============================================================================

void registerClient() {
  StaticJsonDocument<1024> doc;
  doc["type"] = "register";
  doc["client_name"] = clientName;
  
  // Define topics
  JsonArray topics = doc["topics"].to<JsonArray>();
  topics.add("sensors/temperature");
  topics.add("sensors/humidity");
  
  // Define topic metadata
  JsonObject metadata = doc["topic_metadata"].to<JsonObject>();
  
  // Temperature metadata
  JsonObject tempMeta = metadata["sensors/temperature"].to<JsonObject>();
  tempMeta["description"] = "Temperature sensor reading";
  tempMeta["unit"] = "°C";
  tempMeta["sampling_rate"] = TEMP_SAMPLING_RATE;
  
  // Humidity metadata
  JsonObject humMeta = metadata["sensors/humidity"].to<JsonObject>();
  humMeta["description"] = "Humidity sensor reading";
  humMeta["unit"] = "%";
  humMeta["sampling_rate"] = HUMIDITY_SAMPLING_RATE;
  
  // Serialize and send
  String registration;
  serializeJson(doc, registration);
  
  Serial.println("Sending registration...");
  Serial.println(registration);
  
  webSocket.sendTXT(registration);
}

// ============================================================================
// MESSAGE HANDLER
// ============================================================================

void handleMessage(String message) {
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.print("JSON deserialization failed: ");
    Serial.println(error.c_str());
    return;
  }
  
  String type = doc["type"] | "";
  
  if (type == "registration_response") {
    String status = doc["status"] | "";
    
    if (status == "accepted") {
      Serial.println("✓ Registration ACCEPTED!");
      isRegistered = true;
      
      // Extract and sync system time
      if (doc.containsKey("system_time")) {
        JsonObject sysTime = doc["system_time"];
        if (sysTime.containsKey("timestamp_ms")) {
          // Server time is Unix timestamp in milliseconds (since epoch)
          // ESP32's unsigned long is 32-bit (max ~4.3 billion)
          // Unix timestamp in ms for year 2024 is ~1.7 trillion, so we need 64-bit
          unsigned long long serverTime = sysTime["timestamp_ms"];  // Unix timestamp in ms (64-bit)
          unsigned long clientTime = millis();  // Milliseconds since ESP32 boot (32-bit is fine)
          
          // Validate server time is reasonable (should be > 1 trillion for recent years)
          if (serverTime < 1000000000000ULL) {  // Less than year 2001
            Serial.println("WARNING: Server timestamp seems invalid!");
            Serial.print("  Received: ");
            Serial.println(serverTime);
          }
          
          // Store the boot time millis() value at registration
          bootTimeMillis = clientTime;
          
          // Calculate offset: serverUnixTime - bootTimeMillis
          // When sending data: timestamp = millis() + serverTimeOffset
          // This gives: timestamp = current_millis + (serverUnixTime - bootTimeMillis)
          // Which equals: timestamp = serverUnixTime + (current_millis - bootTimeMillis)
          // This correctly converts millis() to Unix timestamp
          serverTimeOffset = serverTime - (unsigned long long)clientTime;
          
          Serial.println("Server time synchronized!");
          Serial.print("  Server Unix time: ");
          Serial.print(serverTime);
          Serial.print(" ms (");
          Serial.print(serverTime / 1000ULL);
          Serial.println(" seconds since epoch)");
          Serial.print("  Client boot time (millis): ");
          Serial.println(clientTime);
          Serial.print("  Calculated offset: ");
          Serial.print(serverTimeOffset);
          Serial.println(" ms");
          
          // Verify calculation
          unsigned long long testTimestamp = (unsigned long long)millis() + serverTimeOffset;
          Serial.print("  Test timestamp (now + offset): ");
          Serial.print(testTimestamp);
          Serial.print(" ms (");
          Serial.print(testTimestamp / 1000ULL);
          Serial.println(" seconds since epoch)");
        } else {
          Serial.println("WARNING: system_time.timestamp_ms not found in registration response!");
        }
      } else {
        Serial.println("WARNING: system_time not found in registration response!");
      }
      
      // Print server info
      if (doc.containsKey("server_info")) {
        JsonObject serverInfo = doc["server_info"];
        Serial.print("Server IP: ");
        Serial.println(serverInfo["ip"] | "unknown");
        Serial.print("Server Port: ");
        Serial.println(serverInfo["port"] | "unknown");
      }
      
      Serial.println("Ready to send data!");
      
    } else if (status == "rejected") {
      Serial.println("✗ Registration REJECTED!");
      String msg = doc["message"] | "Unknown error";
      Serial.println("Reason: " + msg);
      isRegistered = false;
      
      // If rejected due to duplicate name, suggest changing client name
      if (msg.indexOf("already exists") >= 0) {
        Serial.println("\n*** IMPORTANT: Change 'clientName' in the code! ***");
        Serial.println("Your client name must be unique.");
      }
    }
    
  } else if (type == "ping") {
    // Handle ping message
    String pingId = doc["ping_id"] | "";
    unsigned long timestamp = doc["timestamp"] | millis();
    
    lastPingReceived = millis();
    
    // Send pong response
    StaticJsonDocument<128> pongDoc;
    pongDoc["type"] = "pong";
    pongDoc["ping_id"] = pingId;
    pongDoc["timestamp"] = millis();
    
    String pong;
    serializeJson(pongDoc, pong);
    webSocket.sendTXT(pong);
    
    Serial.print("Ping received (ID: ");
    Serial.print(pingId);
    Serial.println(") - Pong sent");
    
  } else {
    Serial.print("Unknown message type: ");
    Serial.println(type);
  }
}

// ============================================================================
// DATA PUBLISHING
// ============================================================================

void sendTemperatureData() {
  // Calculate Unix timestamp: serverUnixTime + (current_millis - bootTimeMillis)
  // Which equals: millis() + serverTimeOffset
  // Use 64-bit for Unix timestamps (milliseconds since epoch)
  unsigned long currentMillis = millis();
  unsigned long long unixTimestamp = (unsigned long long)currentMillis + serverTimeOffset;
  
  // Validate timestamp is reasonable (should be > 1 trillion for recent years)
  if (unixTimestamp < 1000000000000ULL) {
    Serial.print("ERROR: Invalid timestamp calculated! ");
    Serial.print("currentMillis=");
    Serial.print(currentMillis);
    Serial.print(", serverTimeOffset=");
    Serial.print(serverTimeOffset);
    Serial.print(", result=");
    Serial.println(unixTimestamp);
    // Don't send invalid data
    return;
  }
  
  // Create fresh JSON document for temperature data
  StaticJsonDocument<256> tempDoc;
  tempDoc["type"] = "data";
  tempDoc["topic"] = "sensors/temperature";  // Explicitly set temperature topic
  tempDoc["data"]["value"] = temperature;   // Use temperature variable
  tempDoc["data"]["sensor_id"] = "TEMP_001";
  tempDoc["timestamp"] = unixTimestamp;  // Unix timestamp in milliseconds (64-bit)
  
  String tempMessage;
  serializeJson(tempDoc, tempMessage);
  webSocket.sendTXT(tempMessage);
  
  Serial.print("Published temperature: ");
  Serial.print(temperature);
  Serial.print(" °C (timestamp: ");
  Serial.print(unixTimestamp);
  Serial.print(" = ");
  Serial.print(unixTimestamp / 1000ULL);
  Serial.println(" seconds since epoch)");
}

void sendHumidityData() {
  // Calculate Unix timestamp: serverUnixTime + (current_millis - bootTimeMillis)
  // Which equals: millis() + serverTimeOffset
  // Use 64-bit for Unix timestamps (milliseconds since epoch)
  unsigned long currentMillis = millis();
  unsigned long long unixTimestamp = (unsigned long long)currentMillis + serverTimeOffset;
  
  // Validate timestamp is reasonable (should be > 1 trillion for recent years)
  if (unixTimestamp < 1000000000000ULL) {
    Serial.print("ERROR: Invalid timestamp calculated! ");
    Serial.print("currentMillis=");
    Serial.print(currentMillis);
    Serial.print(", serverTimeOffset=");
    Serial.print(serverTimeOffset);
    Serial.print(", result=");
    Serial.println(unixTimestamp);
    // Don't send invalid data
    return;
  }
  
  // Create fresh JSON document for humidity data
  StaticJsonDocument<256> humDoc;
  humDoc["type"] = "data";
  humDoc["topic"] = "sensors/humidity";  // Explicitly set humidity topic
  humDoc["data"]["value"] = humidity;   // Use humidity variable
  humDoc["data"]["sensor_id"] = "HUM_001";
  humDoc["timestamp"] = unixTimestamp;  // Unix timestamp in milliseconds (64-bit)
  
  String humMessage;
  serializeJson(humDoc, humMessage);
  webSocket.sendTXT(humMessage);
  
  Serial.print("Published humidity: ");
  Serial.print(humidity);
  Serial.print(" % (timestamp: ");
  Serial.print(unixTimestamp);
  Serial.print(" = ");
  Serial.print(unixTimestamp / 1000ULL);
  Serial.println(" seconds since epoch)");
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

unsigned long long getSynchronizedTime() {
  // Returns Unix timestamp in milliseconds (64-bit)
  // Formula: serverUnixTime + (current_millis - bootTimeMillis) = millis() + serverTimeOffset
  return (unsigned long long)millis() + serverTimeOffset;
}

