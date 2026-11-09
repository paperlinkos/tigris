import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class IdeaChatMessage {
  final String role;
  final String content;
  const IdeaChatMessage(this.role, this.content);
  Map<String, String> toJson() => {'role': role, 'content': content};
}

class IdeaChatSettings {
  final String endpoint;
  final String model;
  final String provider;
  const IdeaChatSettings({
    required this.endpoint,
    required this.model,
    required this.provider,
  });

  static const openRouter = IdeaChatSettings(
    provider: 'OpenRouter',
    endpoint: 'https://openrouter.ai/api/v1/chat/completions',
    model: 'openrouter/free',
  );
  static const gemini = IdeaChatSettings(
    provider: 'Gemini',
    endpoint:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    model: 'gemini-3.8-flash',
  );

  Map<String, String> toJson() => {
    'endpoint': endpoint,
    'model': model,
    'provider': provider,
  };
  factory IdeaChatSettings.fromJson(Map<String, dynamic> json) =>
      IdeaChatSettings(
        endpoint: json['endpoint']?.toString() ?? openRouter.endpoint,
        model: json['model']?.toString() ?? openRouter.model,
        provider: json['provider']?.toString() ?? openRouter.provider,
      );
}

abstract class IdeaChatCredentials {
  Future<IdeaChatSettings> loadSettings();
  Future<String?> loadKey();
  Future<void> save(IdeaChatSettings settings, String key);
  Future<void> clear();
}

class SecureIdeaChatCredentials implements IdeaChatCredentials {
  static const _settingsKey = 'idea_chat_settings';
  static const _apiKey = 'idea_chat_api_key';
  final FlutterSecureStorage _storage;
  SecureIdeaChatCredentials({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  @override
  Future<IdeaChatSettings> loadSettings() async {
    final raw = await _storage.read(key: _settingsKey);
    if (raw == null) return IdeaChatSettings.openRouter;
    try {
      return IdeaChatSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return IdeaChatSettings.openRouter;
    }
  }

  @override
  Future<String?> loadKey() => _storage.read(key: _apiKey);
  @override
  Future<void> save(IdeaChatSettings settings, String key) async {
    await _storage.write(
      key: _settingsKey,
      value: jsonEncode(settings.toJson()),
    );
    await _storage.write(key: _apiKey, value: key.trim());
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _settingsKey);
    await _storage.delete(key: _apiKey);
  }
}

class IdeaChatException implements Exception {
  final String message;
  const IdeaChatException(this.message);
  @override
  String toString() => message;
}

class IdeaChatService {
  final IdeaChatCredentials credentials;
  final http.Client _client;
  IdeaChatService({IdeaChatCredentials? credentials, http.Client? client})
    : credentials = credentials ?? SecureIdeaChatCredentials(),
      _client = client ?? http.Client();

  Future<String> reply({
    required String ideaContext,
    required List<IdeaChatMessage> messages,
  }) async {
    final settings = await credentials.loadSettings();
    final key = await credentials.loadKey();
    if (key == null || key.trim().isEmpty) {
      throw const IdeaChatException(
        'Add an API key in Settings before starting a brainstorm.',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.parse(settings.endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': settings.model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You help refine one idea. Be practical, concise, and ask one useful question at a time. Do not claim to have saved or changed anything.\n\nIDEA CONTEXT:\n$ideaContext',
                },
                ...messages.map((message) => message.toJson()),
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map
            ? (decoded['error'] is Map
                  ? decoded['error']['message']
                  : decoded['message'])
            : null;
        throw IdeaChatException(
          (error?.toString().trim().isNotEmpty ?? false)
              ? error.toString()
              : 'The AI provider returned ${response.statusCode}. Try again later.',
        );
      }
      String? content;
      if (decoded is Map) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final message = (choices.first as Map)['message'];
          if (message is Map) {
            content = message['content']?.toString();
          }
        }
      }
      if (content == null || content.trim().isEmpty) {
        throw const IdeaChatException(
          'The AI provider returned an empty reply.',
        );
      }
      return content.trim();
    } on TimeoutException {
      throw const IdeaChatException('The AI request timed out. Try again.');
    } on SocketException {
      throw const IdeaChatException(
        'No network connection. Try again when you are online.',
      );
    } on FormatException {
      throw const IdeaChatException(
        'The AI provider returned an unreadable response.',
      );
    }
  }
}
