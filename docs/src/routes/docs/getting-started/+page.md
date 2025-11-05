# Getting Started with ESP32 and BP Mobile

This guide will walk you through setting up your ESP32 device to connect to the BP Mobile app.

## Prerequisites

- ESP32 development board (ESP32, ESP32-S2, ESP32-S3, etc.)
- Arduino IDE or PlatformIO
- WiFi network access or hotspot capability
- BP Mobile app installed on Android/iOS device

## Quick Start

1. **Enable External Publisher in BP Mobile**
   - Open the BP Mobile app
   - Navigate to "Publishers" view
   - Enable the "External (ESP32)" publisher
   - Note the WebSocket URL displayed (e.g., `ws://192.168.43.1:3000`)

2. **Connect Your ESP32**
   - If using hotspot: Connect ESP32 to the phone's hotspot
   - If using WiFi: Connect ESP32 to the same WiFi network as your phone

3. **Upload Example Code**
   - See the [Code Examples](/docs/examples) page for ready-to-use Arduino sketches

## Network Configuration

### Option 1: Using Phone Hotspot (Recommended for Mobile Use)

1. Enable hotspot on your phone
2. Check the IP address in BP Mobile → Network Management
3. Connect ESP32 to the hotspot network
4. Use the hotspot IP address in your ESP32 code

### Option 2: Using Shared WiFi Network

1. Connect your phone to a WiFi network
2. Check the LAN IP in BP Mobile → Network Management
3. Connect ESP32 to the same WiFi network
4. Use the LAN IP address in your ESP32 code

## Next Steps

- Read the [Connection Guide](/docs/connection) for detailed connection steps
- Review the [WebSocket Protocol](/docs/protocol) for message formats
- Check out [Code Examples](/docs/examples) for implementation samples

