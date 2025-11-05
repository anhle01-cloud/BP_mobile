import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models/session.dart';
import '../../providers/experiment_provider.dart';
import '../../repositories/experiment_repository.dart';

final experimentSessionsProvider =
    FutureProvider.family<List<Session>, int>((ref, experimentId) async {
  final repository = ref.watch(experimentRepositoryProvider);
  final sessions = await repository.getSessionsByExperimentId(experimentId);
  // Sort by session number descending (most recent first)
  sessions.sort((a, b) => b.sessionNumber.compareTo(a.sessionNumber));
  return sessions;
});

class SessionsHistoryScreen extends ConsumerWidget {
  final int experimentId;

  const SessionsHistoryScreen({super.key, required this.experimentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Invalidate to force refresh when screen is displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(experimentSessionsProvider(experimentId));
    });
    
    final sessionsAsync = ref.watch(experimentSessionsProvider(experimentId));
    final experimentAsync = ref.watch(experimentProvider(experimentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(experimentSessionsProvider(experimentId));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: experimentAsync.when(
        data: (experiment) {
          return Column(
            children: [
              if (experiment != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    experiment.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              const Divider(),
              Expanded(
                child: sessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 64,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No recording sessions yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _buildSessionCard(context, ref, session);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.main,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: $error'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, WidgetRef ref, Session session) {
    final startDate =
        DateTime.fromMillisecondsSinceEpoch(session.startTimestamp);
    final endDate = session.endTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(session.endTimestamp!)
        : null;

    final duration = endDate != null
        ? endDate.difference(startDate)
        : DateTime.now().difference(startDate);

    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      if (hours > 0) {
        return '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${seconds}s';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent,
          child: Text(
            '${session.sessionNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'Session ${session.sessionNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'export') {
              final repository = ref.read(experimentRepositoryProvider);
              await _exportSession(context, repository, session);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Text('Export Session'),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Started: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (endDate != null)
              Text(
                'Ended: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(endDate)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Duration: ${formatDuration(duration)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.data_object, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Entries: ${session.entryCount}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _exportSession(BuildContext context, ExperimentRepository repository, Session session) async {
    try {
      
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Get export directory
      final exportDir = await repository.getExportDirectory();
      if (exportDir.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access export directory'),
              backgroundColor: AppColors.main,
            ),
          );
        }
        return;
      }

      // Create filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'session_${session.sessionNumber}_$timestamp.json';
      final filePath = '$exportDir/$filename';

      // Write to file
      await repository.exportSessionToFile(session.id!, filePath);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exported to: $filename', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  filePath,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.main,
          ),
        );
      }
    }
  }
}

