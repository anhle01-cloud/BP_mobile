import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../providers/experiment_provider.dart';
import '../../providers/recording_provider.dart';
import '../../repositories/experiment_repository.dart';
import '../experiments/experiment_list_screen.dart';
import '../publishers/publishers_view_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/network_settings_screen.dart';
import '../settings/client_management_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  Future<Map<String, dynamic>>? _dashboardDataFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _refreshDashboardData(WidgetRef ref) {
    final repository = ref.read(experimentRepositoryProvider);
    _dashboardDataFuture = _getDashboardData(repository);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BP Mobile'),
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(context, ref),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppColors.main,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science),
            label: 'Experiments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Publishers',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.main,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BP Mobile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data Logger',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('Network Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: const Text('Client Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return const ExperimentListScreen();
      case 2:
        return const PublishersViewScreen();
      default:
        return _buildDashboardView();
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context, WidgetRef ref) {
    // Only watch isRecording status, not the entire state to avoid frequent rebuilds
    final recordingState = ref.watch(recordingStateProvider);
    
    if (!recordingState.isRecording) {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: () => _stopRecording(context, ref, recordingState),
      backgroundColor: AppColors.main,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.stop),
      label: Text(
        recordingState.activeExperiment != null
            ? 'Stop: ${recordingState.activeExperiment!.name}'
            : 'Stop Recording',
      ),
    );
  }

  Future<void> _stopRecording(
    BuildContext context,
    WidgetRef ref,
    RecordingState recordingState,
  ) async {
    // Stop immediately without confirmation for faster response
    await ref.read(recordingStateProvider.notifier).stopRecording();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording stopped'),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDashboardView() {
    // Watch recording state for real-time updates during recording
    final recordingState = ref.watch(recordingStateProvider);
    
    // Use cached future to prevent unnecessary rebuilds
    if (_dashboardDataFuture == null) {
      _refreshDashboardData(ref);
    }
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data ?? {};
        // Use recording state values if recording, otherwise use cached data
        final totalStorage = recordingState.isRecording 
            ? recordingState.storageSizeBytes 
            : (data['totalStorage'] as int? ?? 0);
        final totalEntries = recordingState.isRecording
            ? recordingState.totalEntries
            : (data['totalEntries'] as int? ?? 0);
        final totalExperiments = data['totalExperiments'] as int? ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            _refreshDashboardData(ref);
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System Time Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColors.accent),
                            const SizedBox(width: 8),
                            const Text(
                              'System Time',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<DateTime>(
                          stream: Stream.periodic(
                            const Duration(seconds: 1),
                            (_) => DateTime.now(),
                          ),
                          builder: (context, snapshot) {
                            final now = snapshot.data ?? DateTime.now();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('yyyy-MM-dd').format(now),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm:ss').format(now),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Stats Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Quick Stats',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (recordingState.isRecording) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.main,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.main,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickStat(
                              'Experiments',
                              totalExperiments.toString(),
                              Icons.science,
                            ),
                            _buildQuickStat(
                              'Entries',
                              totalEntries.toString(),
                              Icons.data_object,
                            ),
                            _buildQuickStat(
                              'Storage',
                              _formatBytesShort(totalStorage),
                              Icons.storage,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatBytesShort(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}G';
  }

  Future<Map<String, dynamic>> _getDashboardData(
    ExperimentRepository repository,
  ) async {
    // Clean up orphaned entries first
    await repository.cleanupOrphanedEntries();
    
    final totalStorage = await repository.getStorageSizeEstimate();
    final totalEntries = await repository.getTotalDataEntriesCount();
    final experiments = await repository.getAllExperiments();

    return {
      'systemTime': DateTime.now(),
      'totalStorage': totalStorage,
      'totalEntries': totalEntries,
      'totalExperiments': experiments.length,
    };
  }
}

