import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../services/network_settings_service.dart';
import '../../providers/publisher_provider.dart';
import '../../services/network_manager.dart';

class NetworkSettingsScreen extends ConsumerStatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  ConsumerState<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends ConsumerState<NetworkSettingsScreen> {
  final TextEditingController _portController = TextEditingController();
  final NetworkSettingsService _networkSettings = NetworkSettingsService();
  final NetworkManager _networkManager = NetworkManager();
  bool _isLoading = false;
  bool _isRestarting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final port = await _networkSettings.getPort();
      _portController.text = port.toString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: AppColors.main,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePort() async {
    final port = int.tryParse(_portController.text);
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Port must be a number between 1 and 65535'),
          backgroundColor: AppColors.main,
        ),
      );
      return;
    }

    try {
      setState(() => _isRestarting = true);
      
      // Save port
      await _networkSettings.setPort(port);
      
      // Restart WebSocket server if it's running
      final manager = ref.read(publisherManagerProvider);
      if (manager.isPublisherEnabled('external')) {
        await manager.restartWebSocketServer(newPort: port);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Port saved and server restarted'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving port: $e'),
            backgroundColor: AppColors.main,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(publisherManagerProvider);
    final isExternalEnabled = manager.isPublisherEnabled('external');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Settings'),
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // WebSocket Server Settings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WebSocket Server',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Port',
                            hintText: '3000',
                            border: const OutlineInputBorder(),
                            suffixText: '1-65535',
                            helperText: 'Port number for WebSocket server',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isRestarting ? null : _savePort,
                            icon: _isRestarting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_isRestarting ? 'Restarting...' : 'Save & Restart Server'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (isExternalEnabled) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Note: Server will restart with new port',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Network Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, String?>>(
                          future: _getNetworkInfo(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final info = snapshot.data ?? {};
                            final hotspotIp = info['hotspot_ip'] ?? 'Not available';
                            final lanIp = info['lan_ip'] ?? 'Not available';
                            final isHotspot = info['is_hotspot'] == 'true';
                            final currentIp = isHotspot ? hotspotIp : lanIp;
                            
                            return Column(
                              children: [
                                _buildInfoRow(
                                  'Connection Mode',
                                  isHotspot ? 'Hotspot' : 'WiFi',
                                  Icons.wifi,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Current IP Address',
                                  currentIp,
                                  Icons.my_location,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Hotspot IP',
                                  hotspotIp,
                                  Icons.wifi_tethering,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'LAN IP',
                                  lanIp,
                                  Icons.router,
                                ),
                                const SizedBox(height: 8),
                                if (isExternalEnabled)
                                  FutureBuilder<Map<String, String?>>(
                                    future: manager.getWebSocketServerInfo(),
                                    builder: (context, serverSnapshot) {
                                      if (serverSnapshot.connectionState == ConnectionState.waiting) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      final serverInfo = serverSnapshot.data ?? {};
                                      final serverIp = serverInfo['ip'] ?? 'Unknown';
                                      final serverPort = serverInfo['port'] ?? 'Unknown';
                                      final serverUrl = serverInfo['url'] ?? 'Unknown';
                                      
                                      return Column(
                                        children: [
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(
                                            'Server IP',
                                            serverIp,
                                            Icons.dns,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(
                                            'Server Port',
                                            serverPort,
                                            Icons.numbers,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(
                                            'WebSocket URL',
                                            serverUrl,
                                            Icons.link,
                                            isSelectable: true,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<Map<String, String?>> _getNetworkInfo() async {
    try {
      final isHotspot = await _networkManager.isHotspotActive();
      final hotspotIp = await _networkManager.getHotspotIpAddress();
      final lanIp = await _networkManager.getLanIpAddress();
      
      return {
        'is_hotspot': isHotspot.toString(),
        'hotspot_ip': hotspotIp,
        'lan_ip': lanIp,
      };
    } catch (e) {
      return {
        'is_hotspot': 'false',
        'hotspot_ip': 'Error: $e',
        'lan_ip': 'Error: $e',
      };
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isSelectable = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: isSelectable
              ? SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
        ),
      ],
    );
  }
}

