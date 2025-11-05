/// Topic history entry for displaying last N entries
class TopicHistoryEntry {
  final String topicName;
  final Map<String, dynamic> data;
  final int timestamp;
  final String entryId;

  TopicHistoryEntry({
    required this.topicName,
    required this.data,
    required this.timestamp,
    required this.entryId,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

/// Topic history cache - stores last N entries per topic
class TopicHistoryCache {
  final Map<String, List<TopicHistoryEntry>> _history = {};
  final int maxEntriesPerTopic;

  TopicHistoryCache({this.maxEntriesPerTopic = 5});

  /// Add entry to topic history
  void addEntry(String topicName, Map<String, dynamic> data, int timestamp, String entryId) {
    if (!_history.containsKey(topicName)) {
      _history[topicName] = [];
    }

    final entries = _history[topicName]!;
    entries.add(TopicHistoryEntry(
      topicName: topicName,
      data: data,
      timestamp: timestamp,
      entryId: entryId,
    ));

    // Keep only last N entries
    if (entries.length > maxEntriesPerTopic) {
      entries.removeAt(0);
    }
  }

  /// Get last N entries for a topic
  List<TopicHistoryEntry> getEntries(String topicName) {
    return _history[topicName] ?? [];
  }

  /// Get all topics with history
  List<String> getTopics() {
    return _history.keys.toList();
  }

  /// Clear history for a topic
  void clearTopic(String topicName) {
    _history.remove(topicName);
  }

  /// Clear all history
  void clear() {
    _history.clear();
  }

  /// Get entry count for a topic
  int getEntryCount(String topicName) {
    return _history[topicName]?.length ?? 0;
  }
}

