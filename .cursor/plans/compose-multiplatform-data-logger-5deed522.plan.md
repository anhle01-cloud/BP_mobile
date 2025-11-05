<!-- 5deed522-892e-4ab9-9b02-35ac85fa3f4d 7b0a7740-f0dd-43ae-a272-72b49ff31be5 -->
# Flutter Data Logger Implementation Plan

## Architecture Overview

**Publisher Pattern**: Publisher → Topic → Experiment Catalog

- Internal Publishers: GPS, IMU (sensors)
- External Publishers: ESP32 clients via WebSocket/HTTP
- Topics: Tree-like names (e.g., `gps/location`, `imu/acceleration`)
- Experiments: Container for enabled topics with auto-increment recording sessions

**Cross-Platform**: Flutter provides excellent iOS/Android support for WebSocket servers, sensors, and background execution.

## Project Structure

```
BlackPearlMobile/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── experiment.dart
│   │   ├── topic.dart
│   │   └── data_entry.dart
│   ├── database/                 # SQLite setup
│   │   ├── database_helper.dart
│   │   └── schema.sql
│   ├── repositories/             # Data layer
│   │   └── experiment_repository.dart
│   ├── services/
│   │   ├── publishers/           # Sensor publishers
│   │   │   ├── publisher.dart   # Base interface
│   │   │   ├── gps_publisher.dart
│   │   │   ├── imu_publisher.dart
│   │   │   └── external_publisher.dart
│   │   ├── websocket_server.dart # WebSocket server for ESP32
│   │   ├── network_manager.dart  # Hotspot management
│   │   └── recording_service.dart # Background recording service
│   ├── providers/                # State management (Riverpod/Provider)
│   │   ├── experiment_provider.dart
│   │   └── recording_provider.dart
│   └── screens/
│       ├── experiments/          # Experiment list/detail
│       ├── recording/            # Recording console
│       └── settings/             # Settings screen
├── android/                      # Android-specific config
├── ios/                          # iOS-specific config
└── pubspec.yaml                  # Dependencies
```

## Implementation Steps

### 1. Project Setup & Configuration

- Initialize Flutter project with Android and iOS support
- Configure `pubspec.yaml` with dependencies:
  - `sqflite` (SQLite database)
  - `web_socket_channel` (WebSocket server - use `shelf` or `web_socket_channel` with server)
  - `geolocator` (GPS location)
  - `sensors_plus` (IMU sensors)
  - `permission_handler` (permissions)
  - `flutter_riverpod` or `provider` (state management)
  - `path_provider` (database/file paths)
  - `json_serializable` (JSON serialization)
  - `workmanager` (background tasks)

### 2. Data Models

**Files**: `lib/models/`

- `experiment.dart`: id, name, createdAt, isActive
- `topic.dart`: experimentId, name (tree-like), enabled, samplingRate
- `data_entry.dart`: id (auto), timestamp (UNIX), topicName, data (JSON)
- Topic name format: `{source}/{type}` (e.g., `gps/location`, `imu/acceleration`)
- Use `json_serializable` for export/import

### 3. Database Layer

**File**: `lib/database/database_helper.dart`

- **sqflite** (works on both Android/iOS)
- SQLite schema:
  - `experiments` table
  - `topics` table (foreign key to experiments)
  - `data_entries` table: id (INTEGER PRIMARY KEY AUTOINCREMENT), timestamp (INTEGER), topicName (TEXT), data (TEXT as JSON)
- Indexes: (topicName, timestamp) for efficient queries
- JSON1 extension available for optional JSON queries
- Platform-specific database path via `path_provider`

### 4. Repository Layer

**File**: `lib/repositories/experiment_repository.dart`

- CRUD operations for experiments
- Topic management (enable/disable, set sampling rates)
- Data entry insertion (batch inserts for efficiency)
- Export/import functions (JSON per experiment)

### 5. Publisher Architecture

**Files**: `lib/services/publishers/`

- `publisher.dart`: Abstract base class with `start()`, `stop()`, `isActive` stream
- `gps_publisher.dart`: Uses `geolocator`, stabilizes before emitting (>1Hz if available)
- `imu_publisher.dart`: Uses `sensors_plus`, 60Hz sampling
- `external_publisher.dart`: WebSocket endpoint for ESP32
- `topic_publisher.dart`: Wraps publisher with topic name, sampling rate control

### 6. Network Layer (External Publishers)

**Files**:

- `lib/services/websocket_server.dart`: WebSocket server using `shelf` or `web_socket_channel` with server mode
- `lib/services/network_manager.dart`: Platform-specific hotspot management
  - Android: `wifi_iot` package or native channel
  - iOS: Network info display (hotspot creation limited)
- Handle ESP32 connections, route messages to topics
- Default port: 8080

### 7. Background Recording Service

**File**: `lib/services/recording_service.dart`

- Manages active experiment, enabled publishers
- Collects data from publishers, inserts into database
- Provides latest 5 values per topic for console display
- Auto-increment recording session number on record start
- **Android**: Foreground service with notification
- **iOS**: Background location updates + background modes

### 8. State Management

**Files**: `lib/providers/`

- `experiment_provider.dart`: Experiment list, CRUD operations
- `recording_provider.dart`: Recording state, active publishers, latest data entries
- Use Riverpod or Provider for reactive state management

### 9. UI Screens

**Experiment List Screen** (`lib/screens/experiments/experiment_list_screen.dart`)

- List all experiments with name, status, created date
- Actions: Create, Delete, Export, Import
- Navigation to experiment detail

**Experiment Detail/Edit Screen** (`lib/screens/experiments/experiment_detail_screen.dart`)

- Edit experiment name
- Enable/disable topics (GPS, IMU, external)
- Configure sampling rates per topic
- Start/Stop recording button

**Recording Console Screen** (`lib/screens/recording/recording_console_screen.dart`)

- Real-time console showing latest 5 entries per active topic
- Publisher status indicators (active/ready/error)
- Display: topic name, timestamp, data preview
- Stop recording button

**Settings Screen** (`lib/screens/settings/settings_screen.dart`)

- Hotspot configuration (IP, port display)
- Network settings for external publishers

### 10. Platform-Specific Configuration

**Android** (`android/`):

- `AndroidManifest.xml`: Permissions (location, sensors, foreground service)
- Foreground service configuration
- WiFi hotspot permissions

**iOS** (`ios/`):

- `Info.plist`: 
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - Background modes: `location`, `background-processing`
- Network permissions

### 11. Export/Import Format

- Export: JSON file per experiment containing:
  - Experiment metadata
  - Topics configuration
  - Data entries (array of {id, timestamp, topicName, data})
- Import: Validate JSON structure, restore to database

## Key Technical Decisions

1. **Storage**: **sqflite** - cross-platform SQLite, works on both Android/iOS
2. **State Management**: **Riverpod** or **Provider** - reactive, iOS-compatible
3. **GPS**: **geolocator** package - cross-platform location services
4. **IMU**: **sensors_plus** package - cross-platform sensor access
5. **WebSocket Server**: **shelf** or native Dart server implementation
6. **Background Tasks**: **workmanager** for background recording (Android/iOS)
7. **Sampling Rate Control**: Use Dart `Stream.periodic()` or custom rate limiter
8. **GPS Stabilization**: Wait for accuracy threshold before starting data collection
9. **Data Format**: Unix timestamp in milliseconds, data field as serialized JSON string
10. **WebSocket Protocol**: JSON messages with topic name and data payload
11. **Hotspot Management**: Platform-specific (Android full support, iOS limited)
12. **iOS Target**: iOS 14+ (Flutter default)

## Dependencies Required

- `flutter` (UI framework)
- `sqflite` (SQLite database)
- `shelf` or WebSocket server package (WebSocket server)
- `geolocator` (GPS)
- `sensors_plus` (IMU)
- `permission_handler` (permissions)
- `flutter_riverpod` or `provider` (state management)
- `path_provider` (file paths)
- `json_serializable` (JSON)
- `workmanager` (background tasks)
- `wifi_iot` (Android hotspot, optional)

## Advantages of Flutter for This Project

1. **WebSocket Server**: Native Dart can run servers on both platforms
2. **Cross-Platform**: Single codebase for Android/iOS
3. **Mature Ecosystem**: Well-tested packages for sensors, location, database
4. **Background Execution**: Better support for background tasks on both platforms
5. **Hotspot Management**: Platform channels available for Android-specific features
6. **Performance**: Native performance for UI and data processing

### To-dos

- [x] Initialize Flutter project with Android and iOS targets, configure pubspec.yaml with all dependencies
- [ ] Create data models (Experiment, Topic, DataEntry) with json_serializable
- [ ] Implement SQLite database schema and helper using sqflite
- [ ] Create ExperimentRepository with CRUD, export/import, and data entry insertion
- [ ] Define Publisher base class and TopicPublisher wrapper with sampling rate control
- [ ] Implement GpsPublisher (geolocator) and ImuPublisher (sensors_plus) with stabilization and rate limiting
- [ ] Implement WebSocket server (shelf) and platform-specific network manager for hotspot
- [ ] Create RecordingService to manage recording state, collect publisher data, and maintain latest 5 entries per topic
- [ ] Set up Riverpod/Provider for experiment and recording state management
- [ ] Build experiment list and detail/edit screens with CRUD operations
- [ ] Build recording console screen with real-time publisher status and data log display
- [ ] Configure Android permissions, foreground service, and iOS Info.plist with background modes