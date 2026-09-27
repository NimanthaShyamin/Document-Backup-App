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
  /// Default model used for high-speed, cost-effective multimodal extraction
  static const String defaultModelName = 'gemini-1.5-flash';

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
You are an expert vehicle document scanner and analyzer.
Analyze this document file and extract the vehicle document details:
1. vehicleRegNo: The vehicle registration or license plate number (e.g. "WP CAB-1234", "CAB-1234", "19-4821").
2. title: A descriptive and clean document title (e.g. "Vehicle Revenue License 2026/2027", "Comprehensive Motor Insurance", "National Fuel Pass").
3. documentType: Exactly one of: "revenue_license", "insurance_card", "fuel_qr", "custom".
4. policyNo: Policy number or reference number if clearly stated.
5. expiryDate: Expiry date or valid-until date formatted strictly as "YYYY-MM-DD".

Return ONLY a valid JSON object without markdown fences, following this exact schema:
{
  "vehicleRegNo": "string or null",
  "title": "string or null",
  "documentType": "revenue_license | insurance_card | fuel_qr | custom | null",
  "policyNo": "string or null",
  "expiryDate": "YYYY-MM-DD or null"
}
''';

      // 1. Try with official Google Generative AI SDK (with 15s timeout)
      try {
        final model = GenerativeModel(
          model: defaultModelName,
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
          if (parsed != null) return parsed;
        }
      } catch (sdkError) {
        developer.log('[GeminiExtractionService] SDK call failed, trying direct REST fallback: $sdkError');
        final sdkErrorStr = sdkError.toString();
        if (sdkErrorStr.contains('API key not valid') || sdkErrorStr.contains('API_KEY_INVALID')) {
          return ExtractedDocumentDetails.error(
            'Invalid API Key: Google Gemini rejected this key. Please check your key in Settings (Gemini keys start with "AIzaSy...").',
          );
        }

        // 2. Direct REST fallback
        final restResult = await _restApiFallback(
          apiKey: effectiveKey,
          mimeType: mimeType,
          bytes: bytes,
          prompt: prompt,
        );
        if (restResult != null) return restResult;

        return ExtractedDocumentDetails.error(
          'Gemini scanning failed: $sdkErrorStr',
        );
      }
    } catch (e, stack) {
      developer.log('[GeminiExtractionService] Extraction error: $e', error: e, stackTrace: stack);
      return ExtractedDocumentDetails.error('Document analysis error: $e');
    }

    return ExtractedDocumentDetails.empty();
  }

  Future<ExtractedDocumentDetails?> _restApiFallback({
    required String apiKey,
    required String mimeType,
    required List<int> bytes,
    required String prompt,
  }) async {
    try {
      final base64Data = base64Encode(bytes);
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$defaultModelName:generateContent?key=$apiKey',
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
