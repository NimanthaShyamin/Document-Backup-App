import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../../../domain/entities/vehicle_document.dart';

/// Response from the Gemini document Q&A service.
class ChatAnswer {
  final String answer;
  final List<String> relevantDocumentIds;
  final bool found;

  const ChatAnswer({
    required this.answer,
    required this.relevantDocumentIds,
    required this.found,
  });

  factory ChatAnswer.notFound(String question) {
    return const ChatAnswer(
      answer:
          'I couldn\'t find any information about that in your documents. '
          'Make sure the relevant document is imported into the vault.',
      relevantDocumentIds: [],
      found: false,
    );
  }

  factory ChatAnswer.error(String msg) {
    return ChatAnswer(answer: msg, relevantDocumentIds: const [], found: false);
  }
}

/// Gemini-powered conversational assistant that searches across the user's document vault
/// to answer natural language queries (e.g. "What's my TIN number?" / "When does my insurance expire?").
class GeminiChatService {
  static String? _cachedModel;

  final String? apiKey;

  const GeminiChatService({this.apiKey});

  bool get isConfigured => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Ask a natural language question against the user's document vault.
  Future<ChatAnswer> ask({
    required String question,
    required List<VehicleDocument> documents,
  }) async {
    final key = apiKey?.trim();
    if (key == null || key.isEmpty) {
      return ChatAnswer.error(
        'Gemini API key is not configured. Please add your API key in Settings to use AI Chat.',
      );
    }

    if (documents.isEmpty) {
      return ChatAnswer.error(
        'Your vault is empty. Import some documents first, then ask me anything about them!',
      );
    }

    // Build a compact document context
    final docsContext = _buildDocumentContext(documents);

    final prompt = '''
You are a smart personal document assistant. The user has the following documents in their secure vault:

--- DOCUMENTS START ---
$docsContext
--- DOCUMENTS END ---

User question: "$question"

Instructions:
- Search through the documents above to answer the user's question accurately.
- If you find specific values (like ID numbers, TIN numbers, policy numbers, expiry dates), state them clearly.
- Mention which document you found the information in.
- Be concise and helpful.
- If you cannot find relevant information in any document, say so clearly.
- List the DOCUMENT IDs of any relevant documents.

Respond ONLY with this exact JSON (no markdown, no extra text):
{
  "answer": "your natural language answer here",
  "relevantDocumentIds": ["doc-id-1", "doc-id-2"],
  "found": true
}
''';

    final models = await _getModels(key);

    for (final modelName in models) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.2,
          ),
        );
        final response = await model
            .generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 20));
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          final parsed = _parse(text);
          if (parsed != null) {
            _cachedModel = modelName;
            return parsed;
          }
        }
      } catch (e) {
        developer.log('[GeminiChatService] SDK error for $modelName: $e');
        // Try REST fallback
        final rest = await _restFallback(key: key, model: modelName, prompt: prompt);
        if (rest != null) {
          _cachedModel = modelName;
          return rest;
        }
      }
    }

    return ChatAnswer.error(
      'I was unable to analyze your documents at this time. Please check your Gemini API key in Settings.',
    );
  }

  String _buildDocumentContext(List<VehicleDocument> docs) {
    final buf = StringBuffer();
    for (final doc in docs) {
      buf.writeln('---');
      buf.writeln('ID: ${doc.id}');
      buf.writeln('Title: ${doc.title}');
      buf.writeln('Type: ${doc.documentType.label}');
      if (doc.vehicleRegNo.isNotEmpty && doc.vehicleRegNo != 'General') {
        buf.writeln('Reference/Vehicle No: ${doc.vehicleRegNo}');
      }
      if (doc.policyNo != null && doc.policyNo!.isNotEmpty) {
        buf.writeln('Policy/Ref No: ${doc.policyNo}');
      }
      if (doc.expiryDate != null) {
        buf.writeln(
            'Expiry Date: ${doc.expiryDate!.toIso8601String().split('T').first}');
      }
    }
    return buf.toString();
  }

  static bool _isInvalidChatModel(String modelName) {
    final lower = modelName.toLowerCase();
    return lower.contains('tts') ||
        lower.contains('audio') ||
        lower.contains('embedding') ||
        lower.contains('imagen') ||
        lower.contains('aqa') ||
        lower.contains('realtime');
  }

  Future<List<String>> _getModels(String key) async {
    final candidates = <String>[];
    if (_cachedModel != null && !_isInvalidChatModel(_cachedModel!)) {
      candidates.add(_cachedModel!);
    }

    const stableModels = [
      'gemini-flash-lite-latest',
      'gemini-3.1-flash-lite',
      'gemini-3.8-flash',
      'gemini-3-flash-preview',
      'gemini-3.6-flash',
      'gemini-3.5-flash-lite',
      'gemini-flash-latest',
    ];
    for (final sm in stableModels) {
      if (!candidates.contains(sm)) candidates.add(sm);
    }

    try {
      final res = await http
          .get(Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models?key=$key'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final models = body['models'] as List? ?? [];
        for (final m in models) {
          final name = m['name'] as String?;
          final methods =
              (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
          if (name != null && methods.contains('generateContent')) {
            final clean = name.startsWith('models/') ? name.substring(7) : name;
            if (!_isInvalidChatModel(clean) && !candidates.contains(clean)) {
              candidates.add(clean);
            }
          }
        }
      }
    } catch (_) {}

    return candidates;
  }

  Future<ChatAnswer?> _restFallback({
    required String key,
    required String model,
    required String prompt,
  }) async {
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': [{'text': prompt}]}
              ],
              'generationConfig': {
                'temperature': 0.2,
                'responseMimeType': 'application/json',
              }
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final cands = body['candidates'] as List? ?? [];
        if (cands.isNotEmpty) {
          final parts = cands.first['content']?['parts'] as List? ?? [];
          final text = parts.isNotEmpty ? parts.first['text'] as String? : null;
          if (text != null) return _parse(text);
        }
      }
    } catch (e) {
      developer.log('[GeminiChatService] REST fallback error: $e');
    }
    return null;
  }

  ChatAnswer? _parse(String raw) {
    try {
      String clean = raw.trim();
      if (clean.startsWith('```json')) clean = clean.substring(7);
      if (clean.startsWith('```')) clean = clean.substring(3);
      if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
      clean = clean.trim();

      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      return ChatAnswer(
        answer: decoded['answer'] as String? ?? 'No answer found.',
        relevantDocumentIds:
            ((decoded['relevantDocumentIds'] as List?) ?? []).cast<String>(),
        found: decoded['found'] as bool? ?? false,
      );
    } catch (e) {
      developer.log('[GeminiChatService] Failed to parse: $raw, error: $e');
      return null;
    }
  }
}
