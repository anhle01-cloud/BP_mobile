import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../providers/recording_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingStateProvider);
    final isRecording = recordingState.isRecording;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Recording Control Card
          if (isRecording)
            Card(
              color: AppColors.main.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, 
                          color: AppColors.main, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Recording Active',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.main,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (recordingState.activeExperiment != null)
                      Text(
                        'Experiment: ${recordingState.activeExperiment!.name}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Session: ${recordingState.sessionNumber}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Stop Recording'),
                              content: const Text(
                                'Are you sure you want to stop the current recording?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.main,
                                  ),
                                  child: const Text(
                                    'Stop',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirmed == true) {
                            await ref.read(recordingStateProvider.notifier).stopRecording();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Recording stopped'),
                                  backgroundColor: AppColors.accent,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.main,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // App Settings Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App Version'),
                    subtitle: const Text('1.0.0'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('Storage Management'),
                    subtitle: const Text('Manage stored data'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Storage management coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text('Backup & Restore'),
                    subtitle: const Text('Backup experiments to server'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup feature coming in V2'),
                        ),
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
}

