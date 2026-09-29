import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../../domain/entities/document_type.dart';

/// Data class holding metadata extracted by Gemini Vision/Multimodal AI.
class ExtractedDocumentDetails {
  final String? vehicleRegNo;
  final String? title;
  final DocumentType? documentType;
  final String? policyNo;
  final DateTime? expiryDate;
  final bool isAiDetected;
  final String? rawResponse;
  final String? errorMessage;

  const ExtractedDocumentDetails({
    this.vehicleRegNo,
    this.title,
    this.documentType,
    this.policyNo,
    this.expiryDate,
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
      (vehicleRegNo != null && vehicleRegNo!.isNotEmpty) ||
      (title != null && title!.isNotEmpty) ||
      (policyNo != null && policyNo!.isNotEmpty) ||
      expiryDate != null ||
      documentType != null;
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

  /// Discovers available Gemini models for this API key or returns a prioritized fallback list.
  Future<List<String>> _getAvailableModels(String effectiveKey) async {
    final candidates = <String>[];
    if (_cachedWorkingModel != null) {
      candidates.add(_cachedWorkingModel!);
    }

    try {
      final listUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$effectiveKey');
      final res = await http.get(listUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        final models = body['models'] as List?;
        if (models != null) {
          final discovered = <String>[];
          for (final m in models) {
            final name = m['name'] as String?;
            final methods = (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
            if (name != null && methods.contains('generateContent')) {
              final clean = name.startsWith('models/') ? name.substring(7) : name;
              discovered.add(clean);
            }
          }
          if (discovered.isNotEmpty) {
            discovered.sort((a, b) {
              final aFlash = a.toLowerCase().contains('flash');
              final bFlash = b.toLowerCase().contains('flash');
              if (aFlash && !bFlash) return -1;
              if (!aFlash && bFlash) return 1;
              return b.compareTo(a);
            });
            for (final m in discovered) {
              if (!candidates.contains(m)) {
                candidates.add(m);
              }
            }
            return candidates;
          }
        }
      }
    } catch (e) {
      developer.log('[GeminiExtractionService] Model discovery query failed: $e');
    }

    const defaultFallbacks = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash-latest',
      'gemini-2.0-flash-exp',
      'gemini-2.5-flash-lite',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
    ];
    for (final m in defaultFallbacks) {
      if (!candidates.contains(m)) {
        candidates.add(m);
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
        'Gemini API key is not configured. Please add your API key in Settings.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final mimeType = _determineMimeType(file.path);

      const prompt = '''
You are an expert AI document scanner and analyzer.
Analyze this document file and accurately extract its details:
1. title: A descriptive and clean document title (e.g. "National Identity Card", "Sri Lanka Driving License", "Qatar Airways E-Ticket", "Comprehensive Motor Insurance", "Vehicle Revenue License", "Electricity Utility Bill").
2. documentType: Exactly one of: "id_card", "driving_license", "e_ticket", "bill", "certificate", "revenue_license", "insurance_card", "fuel_qr", "custom".
3. vehicleRegNo: If this is a vehicle document, the vehicle registration or license plate number (e.g. "BCM-6416", "WP CAB-1234"). If it is an ID, license, or ticket, the holder name or reference identifier (or null).
4. policyNo: Document reference number, NIC number, license number, booking PNR, policy number, or invoice reference.
5. expiryDate: Expiry date, valid-until date, or travel date formatted strictly as "YYYY-MM-DD" (or null if no expiry).

Return ONLY a valid JSON object without markdown fences, following this exact schema:
{
  "title": "string or null",
  "documentType": "id_card | driving_license | e_ticket | bill | certificate | revenue_license | insurance_card | fuel_qr | custom | null",
  "vehicleRegNo": "string or null",
  "policyNo": "string or null",
  "expiryDate": "YYYY-MM-DD or null"
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
              _cachedWorkingModel = modelName;
              return parsed;
            }
          }
        } catch (sdkError) {
          final sdkErrorStr = sdkError.toString();
          developer.log('[GeminiExtractionService] SDK error for $modelName: $sdkErrorStr');

          if (sdkErrorStr.contains('API key not valid') || sdkErrorStr.contains('API_KEY_INVALID')) {
            return ExtractedDocumentDetails.error(
              'Invalid API Key: Google Gemini rejected this key. Please check your key in Settings (Gemini keys start with "AIzaSy...").',
            );
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
              if (restResult.errorMessage!.contains('NOT_FOUND') ||
                  restResult.errorMessage!.contains('not found')) {
                // Model not found in REST either, proceed to next candidate model
                continue;
              }
              lastErrorMsg = restResult.errorMessage!;
            } else {
              _cachedWorkingModel = modelName;
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
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Data,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'response_mime_type': 'application/json',
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
          errorMsg = 'Invalid Gemini API key. Keys start with "AIzaSy...". Please verify in Settings.';
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
      final typeStr = decoded['documentType'] as String?;
      final expiryStr = decoded['expiryDate'] as String?;

      DocumentType? docType;
      if (typeStr != null && typeStr.isNotEmpty) {
        docType = DocumentType.fromString(typeStr);
      }

      DateTime? expiryDate;
      if (expiryStr != null && expiryStr.isNotEmpty) {
        try {
          expiryDate = DateTime.parse(expiryStr);
        } catch (_) {}
      }

      final details = ExtractedDocumentDetails(
        vehicleRegNo: (regNo != null && regNo.trim().isNotEmpty && regNo != 'null') ? regNo.trim() : null,
        title: (title != null && title.trim().isNotEmpty && title != 'null') ? title.trim() : null,
        documentType: docType,
        policyNo: (policyNo != null && policyNo.trim().isNotEmpty && policyNo != 'null') ? policyNo.trim() : null,
        expiryDate: expiryDate,
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
