import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/document_type.dart';

/// Data class holding metadata extracted by Gemini Vision/Multimodal AI.
class ExtractedDocumentDetails {
  final String? vehicleRegNo;
  final String? title;
  final DocumentType? documentType;
  final String? category;
  final String? policyNo;
  final DateTime? expiryDate;
  final Map<String, dynamic> visibleFields;
  final String? hiddenContext;
  final bool isAiDetected;
  final String? rawResponse;
  final String? errorMessage;

  const ExtractedDocumentDetails({
    this.vehicleRegNo,
    this.title,
    this.documentType,
    this.category,
    this.policyNo,
    this.expiryDate,
    this.visibleFields = const {},
    this.hiddenContext,
    required this.isAiDetected,
    this.rawResponse,
    this.errorMessage,
  });

  factory ExtractedDocumentDetails.empty() {
    return const ExtractedDocumentDetails(isAiDetected: false);
  }

  factory ExtractedDocumentDetails.error(String message) {
    return ExtractedDocumentDetails(
      isAiDetected: false,
      errorMessage: message,
    );
  }

  bool get hasAnyDetail =>
      (title != null && title!.isNotEmpty) ||
      (category != null && category!.isNotEmpty) ||
      (vehicleRegNo != null && vehicleRegNo!.isNotEmpty) ||
      (policyNo != null && policyNo!.isNotEmpty) ||
      expiryDate != null ||
      documentType != null ||
      visibleFields.isNotEmpty;
}

/// Service that leverages Gemini Vision / Multimodal model to scan vehicle document files
/// (.pdf, .png, .jpg, .jpeg) and automatically extract vehicle registration number, title,
/// category, policy number, and expiry date.
class GeminiDocumentExtractionService {
  /// Cached model name that was verified to work on the user's project/account
  static String? _cachedWorkingModel;

  final String? apiKey;

  const GeminiDocumentExtractionService({this.apiKey});

  bool get isConfigured => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Determines the MIME type from the file extension.
  String _determineMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  /// Verified multimodal vision models that reliably support images and PDFs on current Gemini API.
  static const List<String> _verifiedVisionModels = [
    'gemini-flash-lite-latest',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
    'gemini-3.6-flash',
    'gemini-3.8-flash',
    'gemini-3-flash-preview',
  ];

  /// Checks if a model is non-vision (e.g. TTS, audio-only, embedding).
  static bool _isInvalidForVision(String modelName) {
    final lower = modelName.toLowerCase();
    return lower.contains('tts') ||
        lower.contains('audio') ||
        lower.contains('embedding') ||
        lower.contains('imagen') ||
        lower.contains('aqa') ||
        lower.contains('realtime');
  }

  static void _saveWorkingModel(String modelName) {
    _cachedWorkingModel = modelName;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('pref_cached_vision_model', modelName);
    }).catchError((_) {});
  }

  /// Discovers available Gemini models for this API key or returns a prioritized fallback list.
  Future<List<String>> _getAvailableModels(String effectiveKey) async {
    final candidates = <String>[];
    if (_cachedWorkingModel == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _cachedWorkingModel = prefs.getString('pref_cached_vision_model');
      } catch (_) {}
    }

    if (_cachedWorkingModel != null && !_isInvalidForVision(_cachedWorkingModel!)) {
      candidates.add(_cachedWorkingModel!);
    }

    // Always prioritize verified active vision models
    for (final vm in _verifiedVisionModels) {
      if (!candidates.contains(vm)) {
        candidates.add(vm);
      }
    }

    return candidates;
  }

  /// Analyzes the given document file using Gemini AI and returns extracted metadata.
  Future<ExtractedDocumentDetails> extractDetailsFromFile(File file) async {
    final effectiveKey = apiKey?.trim();

    if (effectiveKey == null || effectiveKey.isEmpty) {
      developer.log('[GeminiExtractionService] No Gemini API key provided. Skipping AI extraction.');
      return ExtractedDocumentDetails.error(
        'Gemini API key is not configured. Please add your Google AI Studio API key in Settings.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final mimeType = _determineMimeType(file.path);

      const prompt = '''
You are an expert AI document scanner and analyzer for an all-in-one universal document vault.
Analyze this document file and accurately extract its core details and key metadata:
1. title: A descriptive and clean document title (e.g. "National Identity Card", "Sri Lanka Driving License", "Qatar Airways Flight Ticket", "Motor Insurance Policy", "Vehicle Revenue License", "Electricity Utility Bill", "University Degree Certificate").
2. category: The primary category of the document. Choose the best matching ID from:
   - "id_card" (National ID, Passport, Resident Card)
   - "driving_license" (Driving/Driver's License)
   - "vehicle" (Vehicle Registration, Ownership, CR, Logbook)
   - "bill" (Utility Bill, Tax Assessment, Invoice, Receipt)
   - "e_ticket" (Flight Ticket, Train, Boarding Pass, Event Ticket)
   - "certificate" (Academic, Birth, Marriage, Professional Certificate)
   - "insurance_card" (Health, Vehicle, Life Insurance Policy)
   - "revenue_license" (Annual Vehicle Revenue License)
   - "fuel_qr" (Fuel Pass QR Code)
   - "general" (Any other personal or legal document)
3. expiryDate: Expiry date, valid-until date, due date, or travel date formatted strictly as "YYYY-MM-DD" (or null if the document does not expire).
4. visibleFields: A key-value object of all important identified secondary fields (e.g. "vehicleRegNo", "policyNo", "idNumber", "holderName", "issuer", "accountNo", "amountDue", "seatNo", "vin").
5. hiddenContext: A concise 1-3 sentence summary describing key facts, parties, and context of this document for semantic search.

Return ONLY a valid JSON object without markdown fences, following this exact schema:
{
  "title": "string or null",
  "category": "string or null",
  "expiryDate": "YYYY-MM-DD or null",
  "visibleFields": {
    "key": "value"
  },
  "hiddenContext": "string or null"
}
''';

      final candidateModels = await _getAvailableModels(effectiveKey);
      String lastErrorMsg = 'Failed to analyze document with available Gemini models.';

      for (final modelName in candidateModels) {
        developer.log('[GeminiExtractionService] Attempting extraction with model: $modelName');

        // 1. Try with official Google Generative AI SDK
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: effectiveKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.1,
            ),
          );

          final content = [
            Content.multi([
              TextPart(prompt),
              DataPart(mimeType, bytes),
            ]),
          ];

          final response = await model.generateContent(content).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Gemini AI request timed out after 15 seconds.'),
          );
          final responseText = response.text;

          if (responseText != null && responseText.trim().isNotEmpty) {
            final parsed = _parseJsonDetails(responseText);
            if (parsed != null) {
              _saveWorkingModel(modelName);
              return parsed;
            }
          }
        } catch (sdkError) {
          final sdkErrorStr = sdkError.toString();
          developer.log('[GeminiExtractionService] SDK error for $modelName: $sdkErrorStr');

          if (sdkErrorStr.contains('API key not valid') || sdkErrorStr.contains('API_KEY_INVALID')) {
            return ExtractedDocumentDetails.error(
              'Invalid API Key: Google Gemini rejected this key. Please check your key in Settings.',
            );
          }

          // If this model does not support images, skip immediately to the next candidate
          if (sdkErrorStr.contains('Image input modality is not enabled')) {
            if (_cachedWorkingModel == modelName) _cachedWorkingModel = null;
            continue;
          }

          // If this model is experiencing high demand / 503 / 429 or timeout, skip to next candidate immediately
          final isUnavailable = sdkErrorStr.contains('503') ||
              sdkErrorStr.contains('UNAVAILABLE') ||
              sdkErrorStr.contains('high demand') ||
              sdkErrorStr.contains('RESOURCE_EXHAUSTED') ||
              sdkErrorStr.contains('429') ||
              sdkErrorStr.contains('timed out');
          if (isUnavailable) {
            developer.log('[GeminiExtractionService] Model $modelName is unavailable or timed out. Skipping to next candidate.');
            continue;
          }

          final isNotFound = sdkErrorStr.contains('NOT_FOUND') ||
              sdkErrorStr.contains('not found') ||
              sdkErrorStr.contains('not supported for generateContent');

          if (!isNotFound) {
            lastErrorMsg = sdkErrorStr;
          }

          // 2. Direct REST fallback for this model
          final restResult = await _restApiFallback(
            apiKey: effectiveKey,
            modelName: modelName,
            mimeType: mimeType,
            bytes: bytes,
            prompt: prompt,
          );

          if (restResult != null) {
            if (restResult.errorMessage != null) {
              if (restResult.errorMessage!.contains('API_KEY_INVALID')) {
                return restResult;
              }
              lastErrorMsg = restResult.errorMessage!;
              // Proceed to next candidate model
              continue;
            } else {
              _saveWorkingModel(modelName);
              return restResult;
            }
          }
        }
      }

      return ExtractedDocumentDetails.error(lastErrorMsg);
    } catch (e, stack) {
      developer.log('[GeminiExtractionService] Extraction error: $e', error: e, stackTrace: stack);
      return ExtractedDocumentDetails.error('Document analysis error: $e');
    }
  }

  Future<ExtractedDocumentDetails?> _restApiFallback({
    required String apiKey,
    required String modelName,
    required String mimeType,
    required List<int> bytes,
    required String prompt,
  }) async {
    try {
      final base64Data = base64Encode(bytes);
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
      );

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Data,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection to Gemini REST API timed out.'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final candidates = jsonBody['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'];
          final parts = content?['parts'] as List?;
          final text = parts?.first?['text'] as String?;
          if (text != null) {
            return _parseJsonDetails(text);
          }
        }
      } else {
        String errorMsg = 'Google API error (${response.statusCode})';
        try {
          final Map<String, dynamic> errJson = jsonDecode(response.body);
          if (errJson['error'] != null) {
            final msg = errJson['error']['message'] as String?;
            final status = errJson['error']['status'] as String?;
            if (msg != null && msg.isNotEmpty) {
              errorMsg = '$status: $msg';
            }
          }
        } catch (_) {}

        if (errorMsg.contains('API_KEY_INVALID') || errorMsg.contains('API key not valid')) {
          errorMsg = 'Invalid Gemini API key. Please verify your key in Settings.';
        } else if (errorMsg.contains('SERVICE_DISABLED') || errorMsg.contains('has not been used in project')) {
          errorMsg = 'Generative Language API is disabled in your Google Cloud Project. Please enable it in Google Cloud Console.';
        }

        return ExtractedDocumentDetails.error(errorMsg);
      }
    } catch (e) {
      developer.log('[GeminiExtractionService] REST fallback error: $e');
      return ExtractedDocumentDetails.error('Gemini connection error: $e');
    }
    return null;
  }

  ExtractedDocumentDetails? _parseJsonDetails(String rawText) {
    try {
      // Strip markdown code fences if present
      String cleanJson = rawText.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final dynamic decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) return null;

      final regNo = decoded['vehicleRegNo'] as String?;
      final title = decoded['title'] as String?;
      final policyNo = decoded['policyNo'] as String?;
      final categoryStr = (decoded['category'] ?? decoded['documentType']) as String?;
      final expiryStr = decoded['expiryDate'] as String?;
      final hiddenCtx = decoded['hiddenContext'] as String?;

      Map<String, dynamic> visibleFields = {};
      if (decoded['visibleFields'] is Map) {
        visibleFields = Map<String, dynamic>.from(decoded['visibleFields'] as Map);
      }

      // Preserve legacy vehicle identifiers in visibleFields if present
      if (regNo != null && regNo.trim().isNotEmpty && regNo != 'null' && !visibleFields.containsKey('vehicleRegNo')) {
        visibleFields['vehicleRegNo'] = regNo.trim();
      }
      if (policyNo != null && policyNo.trim().isNotEmpty && policyNo != 'null' && !visibleFields.containsKey('policyNo')) {
        visibleFields['policyNo'] = policyNo.trim();
      }

      DocumentType? docType;
      if (categoryStr != null && categoryStr.isNotEmpty) {
        docType = DocumentType.fromString(categoryStr);
      }

      DateTime? expiryDate;
      if (expiryStr != null && expiryStr.isNotEmpty) {
        try {
          expiryDate = DateTime.parse(expiryStr);
        } catch (_) {}
      }

      final effectiveRegNo = (regNo != null && regNo.trim().isNotEmpty && regNo != 'null')
          ? regNo.trim()
          : (visibleFields['vehicleRegNo'] as String?);

      final effectivePolicyNo = (policyNo != null && policyNo.trim().isNotEmpty && policyNo != 'null')
          ? policyNo.trim()
          : (visibleFields['policyNo'] as String?);

      final details = ExtractedDocumentDetails(
        vehicleRegNo: effectiveRegNo,
        title: (title != null && title.trim().isNotEmpty && title != 'null') ? title.trim() : null,
        documentType: docType,
        category: categoryStr,
        policyNo: effectivePolicyNo,
        expiryDate: expiryDate,
        visibleFields: visibleFields,
        hiddenContext: (hiddenCtx != null && hiddenCtx.trim().isNotEmpty && hiddenCtx != 'null') ? hiddenCtx.trim() : null,
        isAiDetected: true,
        rawResponse: cleanJson,
      );

      return details.hasAnyDetail ? details : null;
    } catch (e) {
      developer.log('[GeminiExtractionService] Failed to parse JSON response: $rawText', error: e);
      return null;
    }
  }
}
