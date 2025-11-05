import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

/// Network manager for hotspot and network information
/// Platform-specific implementations for Android/iOS
class NetworkManager {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get current IP address (WiFi or hotspot)
  Future<String?> getIpAddress() async {
    try {
      if (Platform.isAndroid) {
        return await _networkInfo.getWifiIP();
      } else if (Platform.isIOS) {
        return await _networkInfo.getWifiIP();
      }
    } catch (e) {
      print('Error getting IP address: $e');
    }
    return null;
  }

  /// Get hotspot IP address (Android-specific)
  /// Returns the IP address of the hotspot interface
  Future<String?> getHotspotIpAddress() async {
    try {
      if (Platform.isAndroid) {
        // On Android, hotspot typically uses wlan1 interface
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );

        // Look for hotspot interface (usually wlan1 or ap0)
        for (var interface in interfaces) {
          if (interface.name.contains('wlan1') ||
              interface.name.contains('ap0') ||
              interface.name.contains('ap')) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
                return addr.address;
              }
            }
          }
        }

        // Fallback: Look for any non-loopback address in 192.168.x.x range
        // (common hotspot range)
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('Error getting hotspot IP: $e');
    }
    return null;
  }

  /// Get LAN IP address (WiFi connection)
  /// Returns the IP address when connected to a WiFi network
  Future<String?> getLanIpAddress() async {
    try {
      // First try to get WiFi IP (this works when connected to WiFi)
      final wifiIp = await getIpAddress();
      if (wifiIp != null && !wifiIp.startsWith('192.168.')) {
        // If it's not in hotspot range, it's likely a LAN IP
        return wifiIp;
      }

      // Otherwise, check network interfaces for non-hotspot IPs
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Look for WiFi interface (usually wlan0)
      for (var interface in interfaces) {
        if (interface.name.contains('wlan0') ||
            interface.name.contains('wifi')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('192.168.')) {
              return addr.address;
            }
          }
        }
      }

      // Fallback: return WiFi IP if available
      return wifiIp;
    } catch (e) {
      print('Error getting LAN IP: $e');
    }
    return null;
  }

  /// Check if hotspot is active
  /// On Android, checks if device is acting as hotspot
  /// Returns true if hotspot IP is available and different from WiFi IP
  Future<bool> isHotspotActive() async {
    try {
      final hotspotIp = await getHotspotIpAddress();
      final wifiIp = await getIpAddress();

      // If we have a hotspot IP and it's different from WiFi IP, hotspot is active
      if (hotspotIp != null && hotspotIp != wifiIp) {
        return true;
      }

      // Check if current IP is in hotspot range (192.168.x.x)
      if (wifiIp != null && wifiIp.startsWith('192.168.')) {
        // Check if it's on wlan1 or ap interface (hotspot)
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        for (var interface in interfaces) {
          if (interface.name.contains('wlan1') ||
              interface.name.contains('ap0') ||
              interface.name.contains('ap')) {
            for (var addr in interface.addresses) {
              if (addr.address == wifiIp) {
                return true;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking hotspot status: $e');
    }
    return false;
  }

  /// Get WiFi name (SSID)
  Future<String?> getWifiName() async {
    try {
      if (Platform.isAndroid) {
        return await _networkInfo.getWifiName();
      } else if (Platform.isIOS) {
        return await _networkInfo.getWifiName();
      }
    } catch (e) {
      print('Error getting WiFi name: $e');
    }
    return null;
  }

  /// Check if WiFi is enabled
  Future<bool> isWifiEnabled() async {
    try {
      // network_info_plus doesn't have isWifiEnabled, so we'll check if we can get IP
      final ip = await getIpAddress();
      return ip != null && ip.isNotEmpty;
    } catch (e) {
      print('Error checking WiFi status: $e');
      return false;
    }
  }

  /// Get network information
  Future<Map<String, String?>> getNetworkInfo() async {
    return {
      'ip_address': await getIpAddress(),
      'wifi_name': await getWifiName(),
      'wifi_enabled': (await isWifiEnabled()).toString(),
    };
  }

  /// Note: Hotspot creation/management requires platform-specific implementation
  /// For Android, use platform channels or wifi_iot package
  /// For iOS, hotspot creation is limited by system restrictions
  Future<bool> createHotspot({String? ssid, String? password}) async {
    // Platform-specific implementation needed
    // This would require platform channels or native code
    if (Platform.isAndroid) {
      // Use wifi_iot package or platform channels
      return false; // Not implemented yet
    } else if (Platform.isIOS) {
      // iOS doesn't allow programmatic hotspot creation
      return false;
    }
    return false;
  }
}
