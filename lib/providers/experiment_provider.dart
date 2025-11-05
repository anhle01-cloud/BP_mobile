import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/experiment.dart';
import '../models/topic.dart';
import '../repositories/experiment_repository.dart';
import 'recording_provider.dart';

/// Experiment repository provider
final experimentRepositoryProvider = Provider<ExperimentRepository>((ref) {
  return ExperimentRepository();
});

/// All experiments provider
final experimentsProvider = FutureProvider<List<Experiment>>((ref) async {
  final repository = ref.watch(experimentRepositoryProvider);
  return await repository.getAllExperiments();
});

/// Topics for an experiment provider
final experimentTopicsProvider = FutureProvider.family<List<Topic>, int>((
  ref,
  experimentId,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  return await repository.getTopicsByExperimentId(experimentId);
});

/// Single experiment provider
final experimentProvider = FutureProvider.family<Experiment?, int>((
  ref,
  experimentId,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  return await repository.getExperimentById(experimentId);
});

/// Create experiment provider
final createExperimentProvider = FutureProvider.family<int, String>((
  ref,
  name,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  final experiment = Experiment(name: name, createdAt: now, isActive: false);
  return await repository.createExperiment(experiment);
});

/// Update experiment provider
final updateExperimentProvider = FutureProvider.family<void, Experiment>((
  ref,
  experiment,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  await repository.updateExperiment(experiment);
  ref.invalidate(experimentsProvider);
  ref.invalidate(experimentProvider(experiment.id!));
});

/// Delete experiment provider
final deleteExperimentProvider = FutureProvider.family<void, int>((
  ref,
  experimentId,
) async {
  // Check if this experiment is currently being recorded
  final recordingState = ref.read(recordingStateProvider);
  if (recordingState.isRecording &&
      recordingState.activeExperiment?.id == experimentId) {
    // Stop recording first
    await ref.read(recordingStateProvider.notifier).stopRecording();
  }

  final repository = ref.watch(experimentRepositoryProvider);
  await repository.deleteExperiment(experimentId);
  ref.invalidate(experimentsProvider);
});

/// Create topic provider
final createTopicProvider = FutureProvider.family<int, Topic>((
  ref,
  topic,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  final topicId = await repository.createTopic(topic);
  ref.invalidate(experimentTopicsProvider(topic.experimentId));
  return topicId;
});

/// Update topic provider
final updateTopicProvider = FutureProvider.family<void, Topic>((
  ref,
  topic,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  await repository.updateTopic(topic);
  ref.invalidate(experimentTopicsProvider(topic.experimentId));
});

/// Toggle topic enabled state provider
final toggleTopicProvider = FutureProvider.family<void, Topic>((
  ref,
  topic,
) async {
  final repository = ref.watch(experimentRepositoryProvider);
  await repository.updateTopic(topic.copyWith(enabled: !topic.enabled));
  ref.invalidate(experimentTopicsProvider(topic.experimentId));
});
