# ESP32 Client for BP Mobile

This sketch connects an ESP32 device to the BP Mobile app via WebSocket and publishes sensor data.

## Requirements

### Hardware
- ESP32 development board (ESP32, ESP32-S2, ESP32-S3, ESP32-C3, etc.)
- USB cable for programming

### Software
- Arduino IDE 1.8.19+ or PlatformIO
- ESP32 board support package

### Required Libraries

Install these libraries in Arduino IDE:

1. **WebSockets** by Markus Sattler
   - Go to: `Tools` → `Manage Libraries`
   - Search: "WebSockets"
   - Install: "WebSockets" by Markus Sattler

2. **ArduinoJson** by Benoit Blanchon (recommended)
   - Search: "ArduinoJson"
   - Install: "ArduinoJson" by Benoit Blanchon (version 6.x)

## Setup Instructions

### 1. Configure WiFi

Edit the following lines in `BP_Mobile_Client.ino`:

```cpp
const char* ssid = "YourNetworkSSID";        // Your WiFi/hotspot SSID
const char* password = "YourPassword";        // Your WiFi/hotspot password
```

**For Hotspot Mode:**
- Use the SSID and password of your phone's hotspot
- Enable hotspot on your phone
- Get the hotspot IP from BP Mobile → Network Management

**For Shared WiFi:**
- Use your WiFi network credentials
- Ensure ESP32 and phone are on the same network
- Get the LAN IP from BP Mobile → Network Management

### 2. Configure Server Connection

Edit these lines:

```cpp
const char* serverHost = "192.168.43.1";     // IP from BP Mobile Network Management
const int serverPort = 3000;                  // Port from BP Mobile Network Management
```

**To get the IP and port:**
1. Open BP Mobile app
2. Go to **Hamburger Menu → Network Management**
3. Copy the **IP Address** and **Port**
4. Update the values in the sketch

### 3. Choose a Unique Client Name

```cpp
const char* clientName = "ESP32_Sensor_01";   // Must be unique!
```

**Important:** Each ESP32 device must have a unique client name. If you have multiple devices, change this:
- `ESP32_Sensor_01`
- `ESP32_Sensor_02`
- `ESP32_Actuator_01`
- etc.

### 4. Configure Sampling Rates

```cpp
const float TEMP_SAMPLING_RATE = 10.0;        // Hz (10 samples per second)
const float HUMIDITY_SAMPLING_RATE = 5.0;    // Hz (5 samples per second)
```

Adjust these values based on your sensor capabilities and requirements.

### 5. Enable External Publisher in BP Mobile

1. Open BP Mobile app
2. Navigate to **Publishers** view
3. Enable the **External (ESP32)** publisher toggle
4. Wait for WebSocket server to start (status will show "Active")

### 6. Upload and Monitor

1. Connect ESP32 to your computer via USB
2. Select the correct board in Arduino IDE:
   - `Tools` → `Board` → Select your ESP32 board
   - `Tools` → `Port` → Select the COM port
3. Upload the sketch
4. Open Serial Monitor (115200 baud)
5. Watch for connection status and data publishing

## Expected Output

### Serial Monitor Output:

```
=== BP Mobile ESP32 Client ===
Client Name: ESP32_Sensor_01
Connecting to WiFi: YourNetworkSSID
.....
WiFi connected!
IP address: 192.168.43.2
Signal strength (RSSI): -45 dBm
Connecting to WebSocket server: ws://192.168.43.1:3000
WebSocket Connected
Sending registration...
{"type":"register","client_name":"ESP32_Sensor_01",...}
✓ Registration ACCEPTED!
Server time synchronized. Offset: 1234567890 ms
Server IP: 192.168.43.1
Server Port: 3000
Ready to send data!
Published temperature: 25.5 °C
Published humidity: 60.0 %
Ping received (ID: abc123) - Pong sent
```

### In BP Mobile App:

1. **Client Management** (`Hamburger Menu → Client Management`):
   - Your ESP32 should appear in the "Connected ESP32 Clients" list
   - Connection status: **Active**
   - Connection quality: **Excellent/Good/Fair/Poor**
   - Latency: Should be low (< 50ms for Excellent)

2. **Publishers View**:
   - External (ESP32) publisher should show "Active"
   - WebSocket connection info card should display IP and port

3. **Recording**:
   - Create an experiment
   - Enable topics: `ESP32_Sensor_01/sensors/temperature` and `ESP32_Sensor_01/sensors/humidity`
   - Start recording
   - Data should appear in the recording console

## Troubleshooting

### ESP32 Cannot Connect to WiFi

- **Check SSID and password**: Ensure they match your network/hotspot exactly
- **Check signal strength**: Move ESP32 closer to router/phone
- **Check WiFi mode**: Ensure phone hotspot is enabled (if using hotspot mode)
- **Check network**: Ensure ESP32 and phone are on the same network

### ESP32 Cannot Connect to WebSocket Server

- **Verify server is running**: Check BP Mobile → Publishers → External (ESP32) is enabled
- **Check IP address**: Ensure it matches the IP in BP Mobile → Network Management
- **Check port**: Ensure port matches (default: 3000)
- **Check firewall**: Some phones may block incoming connections

### Registration Rejected: "Client name already exists"

- **Change client name**: Edit `clientName` in the sketch
- **Use unique names**: Each ESP32 must have a different name
- **Recommended format**: `ESP32_DeviceType_Number` (e.g., `ESP32_Sensor_01`)

### Connection Drops Frequently

- **Check WiFi signal**: Ensure strong signal strength
- **Check power supply**: Use stable power source (not USB power from computer)
- **Check connection quality**: Monitor in BP Mobile → Client Management
- **Check ping/pong**: Ensure ping messages are being responded to

### Data Not Appearing in Recording

- **Check topic subscriptions**: Ensure topics are subscribed in Client Management
- **Check topic names**: Must match exactly: `client_name/topic_tree`
- **Check experiment**: Ensure experiment is created and recording is active
- **Check publisher**: Ensure External (ESP32) publisher is enabled

## Adding Real Sensors

Replace the simulated sensor readings with actual sensor code:

```cpp
// Example: DHT22 temperature and humidity sensor
#include <DHT.h>
#define DHTPIN 4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

void setup() {
  // ... existing setup ...
  dht.begin();
}

void loop() {
  // ... existing loop ...
  
  // Read actual sensor
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();
  
  // ... rest of loop ...
}
```

## Customizing Topics

To add more topics:

1. **Add topic to registration**:
```cpp
topics.add("sensors/pressure");
topics.add("actuators/status");
```

2. **Add metadata**:
```cpp
JsonObject pressureMeta = metadata["sensors/pressure"].to<JsonObject>();
pressureMeta["description"] = "Barometric pressure";
pressureMeta["unit"] = "hPa";
pressureMeta["sampling_rate"] = 1.0;
```

3. **Create send function**:
```cpp
void sendPressureData() {
  StaticJsonDocument<256> doc;
  doc["type"] = "data";
  doc["topic"] = "sensors/pressure";
  doc["data"]["value"] = pressure;
  doc["data"]["sensor_id"] = "PRES_001";
  doc["timestamp"] = getSynchronizedTime();
  
  String message;
  serializeJson(doc, message);
  webSocket.sendTXT(message);
}
```

## Next Steps

- Review [Connection Guide](/docs/connection) for detailed setup
- Check [WebSocket Protocol](/docs/protocol) for message format details
- See [Code Examples](/docs/examples) for more examples

