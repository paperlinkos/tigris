import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_responses.dart';
import '../models/flashcard.dart';
import '../models/note_analysis.dart';
import '../models/quiz.dart';
import 'ai_service.dart';

class AiServiceException implements Exception {
  final String message;
  final int? statusCode;

  const AiServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class FirebaseAiService implements AiService {
  final String _functionUrl;
  final http.Client _client;
  final FirebaseAuth? _auth;

  static const String defaultFunctionUrl =
      'https://us-central1-tigris-notes-app.cloudfunctions.net/analyzeNote';

  FirebaseAiService({
    String? functionUrl,
    http.Client? client,
    FirebaseAuth? auth,
  })  : _functionUrl = functionUrl ?? defaultFunctionUrl,
        _client = client ?? http.Client(),
        _auth = auth;

  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NoteAnalysis> analyzeNote({
    required String noteId,
    required String content,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw const AiServiceException('Note content cannot be empty.');
    }

    final authInst = _authInstance;
    final currentUser = authInst?.currentUser;

    if (currentUser == null) {
      throw const AiServiceException(
        'You must be signed in to analyze notes with AI.',
      );
    }

    String? idToken;
    try {
      idToken = await currentUser.getIdToken();
    } catch (e) {
      debugPrint('Failed to get Firebase Auth ID token: $e');
      throw const AiServiceException(
        'Unable to verify authentication. Please sign in again.',
      );
    }

    if (idToken == null || idToken.isEmpty) {
      throw const AiServiceException(
        'Unable to obtain authentication token. Please sign in again.',
      );
    }

    final uri = Uri.parse(_functionUrl);
    final requestBody = jsonEncode({
      'noteId': noteId,
      'content': trimmedContent,
    });

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 50));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const AiServiceException(
            'Received invalid response format from AI service.',
          );
        }
        return NoteAnalysis.fromJson(decoded);
      }

      // Handle non-200 errors with server message if available
      String errorMessage = 'Failed to analyze note (${response.statusCode}).';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson is Map && errorJson['message'] != null) {
          errorMessage = errorJson['message'].toString();
        }
      } catch (_) {}

      switch (response.statusCode) {
        case 400:
          throw AiServiceException(errorMessage, statusCode: 400);
        case 401:
          throw const AiServiceException(
            'Authentication failed. Please sign in again.',
            statusCode: 401,
          );
        case 403:
          throw const AiServiceException(
            'Access denied.',
            statusCode: 403,
          );
        case 502:
          throw AiServiceException(
            errorMessage.isNotEmpty
                ? errorMessage
                : 'AI service encountered an upstream error. Please retry.',
            statusCode: 502,
          );
        case 504:
          throw const AiServiceException(
            'AI analysis request timed out. Please try again.',
            statusCode: 504,
          );
        default:
          throw AiServiceException(errorMessage, statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw const AiServiceException(
        'Connection timed out while waiting for AI analysis. Please try again.',
      );
    } on SocketException {
      throw const AiServiceException(
        'Network error. Please check your internet connection and try again.',
      );
    } on http.ClientException {
      throw const AiServiceException(
        'Network failure communicating with AI service. Please check your connection.',
      );
    } on FormatException {
      throw const AiServiceException(
        'Failed to parse AI response. Please try again.',
      );
    }
  }

  // Phase 1 Scope Restriction: Future features throw until their respective phases
  @override
  Future<AiSummaryResponse> summarizeNote({
    String? noteTitle,
    required String noteContent,
  }) async {
    throw UnimplementedError('Summarization is planned for a future phase.');
  }

  @override
  Future<List<Flashcard>> generateFlashcards({
    required String noteId,
    String? noteTitle,
    required String noteContent,
  }) async {
    throw UnimplementedError('Flashcards are planned for a future phase.');
  }

  @override
  Future<List<QuizQuestion>> generateQuiz({
    required String noteId,
    String? noteTitle,
    required String noteContent,
  }) async {
    throw UnimplementedError('Quizzes are planned for a future phase.');
  }

  @override
  Future<AiExplainResponse> explainNote({
    String? noteTitle,
    required String noteContent,
  }) async {
    throw UnimplementedError('Explanation is planned for a future phase.');
  }

  @override
  Future<TeachMeSession> generateTeachMeSession({
    required String noteId,
    required String noteTitle,
    required String noteContent,
  }) async {
    throw UnimplementedError('Teach Me is planned for a future phase.');
  }

  @override
  Future<TeachMeSession> submitTeachMeAnswer({
    required TeachMeSession session,
    required String userAnswer,
  }) async {
    throw UnimplementedError('Teach Me is planned for a future phase.');
  }
}
