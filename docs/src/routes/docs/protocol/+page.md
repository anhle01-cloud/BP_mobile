# WebSocket Protocol Reference

This document describes the WebSocket message protocol used between ESP32 clients and the BP Mobile app.

## Connection Details

- **Protocol**: WebSocket (WS)
- **Default Port**: 3000 (configurable in Network Management)
- **Message Format**: JSON
- **Heartbeat**: Ping/Pong every 10 seconds

## Message Types

### 1. Client Registration

**From Client to Server:**

```json
{
  "type": "register",
  "client_name": "ESP32_Sensor_01",
  "topics": [
    "sensors/temperature",
    "sensors/humidity",
    "sensors/pressure"
  ],
  "topic_metadata": {
    "sensors/temperature": {
      "description": "Temperature sensor reading",
      "unit": "°C",
      "sampling_rate": 10.0
    },
    "sensors/humidity": {
      "description": "Humidity sensor reading",
      "unit": "%",
      "sampling_rate": 5.0
    },
    "sensors/pressure": {
      "description": "Barometric pressure",
      "unit": "hPa",
      "sampling_rate": 1.0
    }
  }
}
```

**From Server to Client:**

```json
{
  "type": "registration_response",
  "status": "accepted",
  "client_name": "ESP32_Sensor_01",
  "message": "Registration successful",
  "server_info": {
    "ip": "192.168.43.1",
    "port": 3000
  },
  "system_time": {
    "timestamp_ms": 1701889200000,
    "iso8601": "2023-12-07T10:00:00.000Z",
    "timezone_offset_hours": 0
  }
}
```

**Rejection Response:**

```json
{
  "type": "registration_response",
  "status": "rejected",
  "client_name": "ESP32_Sensor_01",
  "message": "Client name already exists. Please choose a different name."
}
```

### 2. Data Publishing

**From Client to Server:**

```json
{
  "type": "data",
  "topic": "sensors/temperature",
  "data": {
    "value": 25.5,
    "sensor_id": "TEMP_001"
  },
  "timestamp": 1701889200000
}
```

**Note**: The server automatically prefixes topics with `client_name/`, so the full topic name becomes `ESP32_Sensor_01/sensors/temperature`.

### 3. Heartbeat (Ping/Pong)

**From Server to Client (Ping):**

```json
{
  "type": "ping",
  "ping_id": "ping_1234567890",
  "timestamp": 1701889200000
}
```

**From Client to Server (Pong):**

```json
{
  "type": "pong",
  "ping_id": "ping_1234567890",
  "timestamp": 1701889200000
}
```

## Topic Naming Convention

Topics use a hierarchical tree structure:

```
client_name/topic_tree
```

**Examples:**
- `ESP32_Sensor_01/sensors/temperature`
- `ESP32_Sensor_01/sensors/humidity`
- `ESP32_Actuator_01/actuators/status`
- `ESP32_Camera_01/image/frame`

## Topic Metadata

Each topic can include metadata for better organization:

```json
{
  "description": "Human-readable description",
  "unit": "Measurement unit (e.g., °C, %, hPa, m/s)",
  "sampling_rate": 10.0  // Hz
}
```

## Timestamps

- **Format**: Unix timestamp in milliseconds
- **Synchronization**: Use `system_time` from registration response to synchronize client clock
- **Example**: `1701889200000` = December 7, 2023, 10:00:00 UTC

## Error Handling

### Registration Errors

- **Duplicate Name**: Choose a different `client_name`
- **Missing Fields**: Ensure all required fields are present
- **Invalid Format**: Verify JSON structure is correct

### Connection Errors

- **Connection Lost**: Reconnect and re-register
- **Server Unavailable**: Check that External Publisher is enabled in BP Mobile
- **Network Issues**: Verify WiFi connection and IP address

## Best Practices

1. **Unique Client Names**: Always use unique, descriptive names
2. **Topic Organization**: Use hierarchical topic names for clarity
3. **Timestamp Synchronization**: Use server time from registration for accurate timestamps
4. **Error Handling**: Implement reconnection logic for network issues
5. **Heartbeat Response**: Always respond to ping messages with pong

## Next Steps

- See [Code Examples](/docs/examples) for implementation samples
- Review [Connection Guide](/docs/connection) for setup instructions

