import 'package:flutter/foundation.dart';

@immutable
class UnknownTerm {
  final String term;
  final String reason;

  const UnknownTerm({
    required this.term,
    required this.reason,
  });

  factory UnknownTerm.fromJson(Map<String, dynamic> json) {
    return UnknownTerm(
      term: json['term']?.toString().trim() ?? '',
      reason: json['reason']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'reason': reason,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownTerm &&
          runtimeType == other.runtimeType &&
          term == other.term &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(term, reason);
}

@immutable
class NoteAnalysis {
  final String title;
  final String date;
  final String service;
  final String speaker;
  final List<String> topics;
  final List<String> keyPoints;
  final List<UnknownTerm> unknownTerms;

  const NoteAnalysis({
    this.title = '',
    this.date = '',
    this.service = '',
    this.speaker = '',
    this.topics = const [],
    this.keyPoints = const [],
    this.unknownTerms = const [],
  });

  factory NoteAnalysis.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'];
    final topics = rawTopics is List
        ? rawTopics.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final rawKeyPoints = json['keyPoints'];
    final keyPoints = rawKeyPoints is List
        ? rawKeyPoints.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final rawUnknownTerms = json['unknownTerms'];
    final unknownTerms = rawUnknownTerms is List
        ? rawUnknownTerms
            .map((e) {
              if (e is Map<String, dynamic>) {
                return UnknownTerm.fromJson(e);
              } else if (e is Map) {
                return UnknownTerm.fromJson(Map<String, dynamic>.from(e));
              } else if (e is String && e.trim().isNotEmpty) {
                return UnknownTerm(
                  term: e.trim(),
                  reason: 'Identified as a specialized or undefined term in the note.',
                );
              }
              return null;
            })
            .whereType<UnknownTerm>()
            .where((u) => u.term.isNotEmpty)
            .toList()
        : <UnknownTerm>[];

    return NoteAnalysis(
      title: json['title']?.toString().trim() ?? '',
      date: json['date']?.toString().trim() ?? '',
      service: json['service']?.toString().trim() ?? '',
      speaker: json['speaker']?.toString().trim() ?? '',
      topics: List.unmodifiable(topics),
      keyPoints: List.unmodifiable(keyPoints),
      unknownTerms: List.unmodifiable(unknownTerms),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'service': service,
        'speaker': speaker,
        'topics': topics,
        'keyPoints': keyPoints,
        'unknownTerms': unknownTerms.map((u) => u.toJson()).toList(),
      };

  bool get isEmpty =>
      title.isEmpty &&
      date.isEmpty &&
      service.isEmpty &&
      speaker.isEmpty &&
      topics.isEmpty &&
      keyPoints.isEmpty &&
      unknownTerms.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteAnalysis &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          date == other.date &&
          service == other.service &&
          speaker == other.speaker &&
          listEquals(topics, other.topics) &&
          listEquals(keyPoints, other.keyPoints) &&
          listEquals(unknownTerms, other.unknownTerms);

  @override
  int get hashCode => Object.hash(
        title,
        date,
        service,
        speaker,
        Object.hashAll(topics),
        Object.hashAll(keyPoints),
        Object.hashAll(unknownTerms),
      );
}
