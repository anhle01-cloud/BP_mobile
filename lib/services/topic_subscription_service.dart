import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing topic subscriptions
/// Subscribed topics are filtered from WebSocket message pool
class TopicSubscriptionService {
  static const String _subscriptionsKey = 'topic_subscriptions';

  /// Get all subscribed topics
  Future<Set<String>> getSubscribedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString(_subscriptionsKey);
    if (subscriptionsJson == null) {
      return <String>{};
    }
    try {
      final List<dynamic> subscriptions = jsonDecode(subscriptionsJson);
      return subscriptions.cast<String>().toSet();
    } catch (e) {
      print('Error parsing topic subscriptions: $e');
      return <String>{};
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeTopic(String topicName) async {
    final subscriptions = await getSubscribedTopics();
    subscriptions.add(topicName);
    await _saveSubscriptions(subscriptions);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeTopic(String topicName) async {
    final subscriptions = await getSubscribedTopics();
    subscriptions.remove(topicName);
    await _saveSubscriptions(subscriptions);
  }

  /// Check if a topic is subscribed
  Future<bool> isSubscribed(String topicName) async {
    final subscriptions = await getSubscribedTopics();
    return subscriptions.contains(topicName);
  }

  /// Subscribe to multiple topics
  Future<void> subscribeTopics(List<String> topicNames) async {
    final subscriptions = await getSubscribedTopics();
    subscriptions.addAll(topicNames);
    await _saveSubscriptions(subscriptions);
  }

  /// Unsubscribe from multiple topics
  Future<void> unsubscribeTopics(List<String> topicNames) async {
    final subscriptions = await getSubscribedTopics();
    subscriptions.removeAll(topicNames);
    await _saveSubscriptions(subscriptions);
  }

  /// Clear all subscriptions
  Future<void> clearSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subscriptionsKey);
  }

  /// Save subscriptions to storage
  Future<void> _saveSubscriptions(Set<String> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = jsonEncode(subscriptions.toList());
    await prefs.setString(_subscriptionsKey, subscriptionsJson);
  }
}

