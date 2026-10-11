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
  final bool requiresAiScan;
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
    this.requiresAiScan = false,
    this.rawResponse,
    this.errorMessage,
  });

  factory ExtractedDocumentDetails.empty() {
    return const ExtractedDocumentDetails(
      isAiDetected: false,
      requiresAiScan: true,
    );
  }

  factory ExtractedDocumentDetails.error(String message) {
    return ExtractedDocumentDetails(
      isAiDetected: false,
      requiresAiScan: true,
      errorMessage: GeminiDocumentExtractionService.sanitizeErrorMessage(message),
    );
  }

  bool get hasAnyDetail =>
      (title != null && title!.isNotEmpty) ||
      (category != null && category!.isNotEmpty) ||
      (vehicleRegNo != null && vehicleRegNo!.isNotEmpty) ||
      (policyNo != null && policyNo!.isNotEmpty) ||
      (hiddenContext != null && hiddenContext!.isNotEmpty) ||
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
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-flash-latest',
  ];

  /// Deprecated models that are no longer available on Google Gemini API.
  static const List<String> _deprecatedVisionModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
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

    if (_cachedWorkingModel != null &&
        !_isInvalidForVision(_cachedWorkingModel!) &&
        !_deprecatedVisionModels.contains(_cachedWorkingModel!)) {
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

  /// Sanitizes raw error strings, stripping private API keys and transforming socket/network exceptions into friendly messages.
  static String sanitizeErrorMessage(String? raw) {
    if (raw == null || raw.isEmpty) return 'An unexpected error occurred.';

    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception with socketexception') ||
        lower.contains('handshakeexception')) {
      return 'Network connection error: Device is offline or server cannot be reached.';
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection.';
    }

    if (lower.contains('resource_exhausted') || lower.contains('429') || lower.contains('quota exceeded')) {
      return 'Gemini API quota exceeded (Rate limit / 429). Will retry after cooldown.';
    }

    if (lower.contains('api_key_invalid') || lower.contains('api key not valid') || lower.contains('invalid api key')) {
      return 'Invalid Gemini API key. Please verify your key in Settings.';
    }

    // Strip private API key query parameter: key=AIza... or key=xxx
    var cleaned = raw.replaceAll(RegExp(r'key=[a-zA-Z0-9_\-]+'), 'key=[REDACTED]');
    // Also strip any full uri=https://... references if they exist
    cleaned = cleaned.replaceAll(RegExp(r'uri=https?://[^\s,\)]+'), '');
    return cleaned.trim();
  }

  /// Analyzes the given document file using Gemini AI and returns extracted metadata.
  /// Optionally accepts user draft fields entered offline for intelligent reconciliation.
  Future<ExtractedDocumentDetails> extractDetailsFromFile(
    File file, {
    String? userDraftTitle,
    String? userDraftCategory,
    DateTime? userDraftExpiryDate,
  }) async {
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

      String prompt = '''
You are an advanced, universal AI document analyzer and vision perception engine.
Analyze this image or document (which can be an invoice, ID card, student ID, driving license, vehicle document, ticket, bill, certificate, receipt, warranty card, general photograph, or any other visual media) and extract structured metadata:

1. "category": Intelligently decide the category. Prioritize matching one of these standard preset IDs if appropriate:
   - "id_card" (National ID, Passport, Residence Permit, Student ID)
   - "driving_license" (Driving License / Driver's Permit)
   - "vehicle" (Vehicle Registration, Ownership, CR, Logbook)
   - "bill" (Utility Bill, Tax Assessment, Invoice, Receipt)
   - "e_ticket" (Flight Ticket, Train/Bus Ticket, Booking Confirmation)
   - "certificate" (Educational, Degree, Birth, Marriage Certificate)
   - "insurance_card" (Health, Motor, Life Insurance Policy)
   - "revenue_license" (Vehicle Revenue License, Road Tax)
   - "fuel_qr" (Fuel Pass QR Code)
   - "photo" or "image" (Non-document photos, landscapes, people, objects, general photography)
   - "general" (Any other personal or legal document)
   If none fit, provide a concise, clean lowercase snake_case category name.

2. "title": A descriptive, clean, official title for the document or image:
   - For documents: Official title (e.g. "National Identity Card", "Student Identity Card", "Comprehensive Motor Insurance", "Laptop Purchase Invoice & Warranty", "Electricity Utility Bill", "Sri Lanka Driving License", "Qatar Airways Flight Ticket").
   - For non-document photos (visual fallback): Describe what you see in a brief descriptive topic (e.g. "Photo of a Sunset", "Portrait of a Man", "Golden Retriever Dog").

3. "expiry_date": The true expiry date, valid-until date, travel date, or payment due date formatted strictly as "YYYY-MM-DD" (or null if the document does not expire or is a general photo).
   IMPORTANT - Contextual Date Arithmetic & Warranty Calculations:
   - When warranties or validity durations are present on an invoice or purchase receipt, DO NOT blindly copy an invoice "Due Date" or invoice date as the expiry date!
   - Perform date arithmetic: Calculate the actual warranty expiration date by adding the warranty duration (in days, months, or years) to the purchase/invoice date.
     Example: An invoice with Date "15/03/2026" and items having "365 DAYS WARRANTY" has an expiry date of 2027-03-15 (15/03/2026 + 365 days). This must become the primary "expiry_date".
   - If secondary warranties exist (e.g. "1050 DAYS SERVICE WARRANTY"): Calculate that date (e.g. 15/03/2026 + 1050 days = 2029-01-28) and record it clearly inside "dynamic_visible_fields" as {"label": "Service Warranty Expiry", "value": "2029-01-28"} (or "28/01/2029") so the user can easily reference it.

4. "dynamic_visible_fields": A JSON array of the 3 to 5 most critical, user-facing details that the user would want to quickly reference on their screen.
   Format as:
   [
     {"label": "ID Number", "value": "..."},
     {"label": "Policy / Ref No", "value": "..."},
     {"label": "Holder Name", "value": "..."}
   ]
   Guidelines:
   - If vehicle document: Include Registration No, Make/Model, Engine/Chassis No, Policy No.
   - If Sri Lankan vehicle document: Standardize Sri Lankan vehicle registration numbers. Recognize 2-letter province prefixes (WP, SP, NP, CP, EP, NW, NC, SG, UP). Extract the core vehicle number cleanly (e.g. "CAB-1234") and note the province separately, or format as {"label": "Registration No", "value": "CAB-1234"}, {"label": "Province", "value": "WP (Western Province)"} so that searches and context identify the core number independently of the province prefix.
   - If invoice / warranty: Include Purchase Date, Total Amount, Product / Serial No, and secondary calculated warranty expirations (e.g. {"label": "Service Warranty Expiry", "value": "28/01/2029"}).
   - If bill: Include Account No, Due Date, or Due Amount.
   - If ID card / passport: Include ID Number, Full Name, Date of Birth.
   - If e-ticket: Include PNR/Booking Ref, Flight/Train No, Departure Date.
   - If general photo / non-document: Keep dynamic_visible_fields minimal or empty [].

5. "hidden_context": Crucially, extract EVERYTHING visible in the document to power deep AI semantic search and chat queries.
   - Include all secondary names, addresses, serial numbers, VIN, engine numbers, transaction IDs, tax IDs, MAC addresses, warranty clauses, shop details, fine print, and timestamps.
   - For Sri Lankan vehicle numbers: Always include BOTH the standalone core registration number (e.g. "CAB-1234") AND the full province-prefixed variations (e.g. "WP CAB-1234", "WP-CAB-1234", "Western Province CAB-1234") so semantic searches match regardless of user input.
   - For non-document photos: Provide a rich visual description of the scene, subjects, objects, colors, environment, and setting.
   Dump this into a single, raw context string.

6. Visual Fallback for Non-Documents (General Photos):
   - If the image is a regular photograph (e.g. a landscape, pet, person, item) that contains little or no text:
     - DO NOT fail or return empty/null metadata!
     - Analyze the visual content: categorize as "Photo" or "Image".
     - Set the "title" to a brief descriptive topic (e.g. "Photo of a Sunset", "Portrait of a Man").
     - Leave "expiry_date" as null.
     - Keep "dynamic_visible_fields" minimal or empty [].
     - Describe what you see in "hidden_context".
''';

      final hasDraftTitle = userDraftTitle != null && userDraftTitle.trim().isNotEmpty;
      final hasDraftCategory = userDraftCategory != null && userDraftCategory.trim().isNotEmpty;
      final hasDraftExpiry = userDraftExpiryDate != null;

      if (hasDraftTitle || hasDraftCategory || hasDraftExpiry) {
        prompt += '''

7. User Draft Reconciliation & Error Re-Correction:
The user previously saved this document in offline/draft mode with the following tentative details:
\${hasDraftTitle ? '- User-Entered Draft Title: "$userDraftTitle"' : ''}
\${hasDraftCategory ? '- User-Entered Draft Category: "$userDraftCategory"' : ''}
\${hasDraftExpiry ? '- User-Entered Draft Expiry Date: "\${userDraftExpiryDate.toIso8601String().split('T').first}"' : ''}

Reconcile these user-entered values against the actual document content:
- Non-Document / Photograph Visual Fallback with User Drafts:
  * If the image is a regular photograph (such as a portrait of a person, selfie, landscape, animal, item, or general scene) containing no document text:
    - The user's draft metadata (such as category "driving_license", "vehicle", or title "test 01", "Untitled", or arbitrary expiry dates) was an OFFLINE PLACEHOLDER or MISTAKE.
    - DISCARD the user draft category and set "category" strictly to "photo".
    - MUST generate a descriptive visual title for what the photo actually shows (e.g. "Portrait of a Professional Man", "Photo of a Sunset", "Portrait of a Man in Suit", "Photo of a Golden Retriever"). DO NOT leave "title" empty or null!
    - Set "expiry_date" strictly to null (photographs never expire).
    - Set "dynamic_visible_fields" to [].
    - Put a comprehensive visual description of the subjects, clothing, environment, and background in "hidden_context".
- Document Title (For text/documents):
  * Check whether the user draft title is meaningful and relevant to what the document actually is:
    a) If the user draft title is meaningless, gibberish (e.g. repeated characters like "ttttt", "aaaa", "asdf", random keystrokes), a generic placeholder ("Untitled", "Document", "New Scan", "test"), or completely incompatible/unrelated to what the document actually is:
       Completely DISCARD the user draft title. Recreate a brand new, accurate, professional, and descriptive title based strictly on what the document actually is (e.g. "Student Identity Card", "National Identity Card", "Vehicle Registration Certificate").
    b) If the user draft title is relevant or partially matches the document topic (e.g. user typed "Student ID", "My Driving License", "Electricity Bill", "University Card"):
       Respect the user's intent, and update/enrich it by appending or inserting missing specific details from the document (e.g. if user typed "Student ID", update to "Student Identity Card - [Institution/Name]"; if user typed "Car License", update to "Revenue License - WP CAB-1234").
    * Output the final resolved title in "title".
- Document Category:
  * If the user draft category is wrong or incompatible with the document (e.g. user selected "revenue_license" or "vehicle" for a Student ID, National ID, Educational Certificate, or Receipt):
    Re-correct the category to the true, accurate category from the preset list (e.g. "id_card", "certificate", "bill", "e_ticket", "photo", "general").
  * Output the accurate category in "category".
- Expiry Date:
  * Accurately determine whether this document truly has an expiration date:
    - If it has an expiration date, output it formatted as "YYYY-MM-DD".
    - If the document does NOT expire (e.g. student ID with no expiration, birth certificate, diploma, general photo, non-expiring ID):
      Set "expiry_date" strictly to null. Do NOT retain the user's mistaken draft expiry date.
''';
      }

      prompt += '''

Return ONLY a valid JSON object without markdown fences, following this exact schema:
{
  "category": "string",
  "title": "string",
  "expiry_date": "YYYY-MM-DD or null",
  "dynamic_visible_fields": [
    {"label": "string", "value": "string"}
  ],
  "hidden_context": "string"
}
''';

      return await Future<ExtractedDocumentDetails>(() async {
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
              const Duration(seconds: 45),
              onTimeout: () => throw TimeoutException('Gemini AI request timed out after 45 seconds.'),
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

            // If quota exhausted (429 / RESOURCE_EXHAUSTED), fail fast to observe cooldown
            if (sdkErrorStr.contains('RESOURCE_EXHAUSTED') || sdkErrorStr.contains('429')) {
              return ExtractedDocumentDetails.error(
                'Gemini API quota exceeded (Rate limit / 429). Will retry after cooldown.',
              );
            }

            // If this model is not found or no longer available, skip immediately to next model without wasting REST upload
            final isNotFound = sdkErrorStr.contains('NOT_FOUND') ||
                sdkErrorStr.contains('not found') ||
                sdkErrorStr.contains('no longer available') ||
                sdkErrorStr.contains('not supported for generateContent');
            if (isNotFound) {
              developer.log('[GeminiExtractionService] Model $modelName is not found or deprecated. Skipping to next candidate.');
              if (_cachedWorkingModel == modelName) _cachedWorkingModel = null;
              continue;
            }

            // If this model does not support images, skip immediately to the next candidate
            if (sdkErrorStr.contains('Image input modality is not enabled')) {
              if (_cachedWorkingModel == modelName) _cachedWorkingModel = null;
              continue;
            }

            // If this model is experiencing high demand / 503, skip to next candidate immediately
            final isUnavailable = sdkErrorStr.contains('503') ||
                sdkErrorStr.contains('UNAVAILABLE') ||
                sdkErrorStr.contains('high demand');
            if (isUnavailable) {
              developer.log('[GeminiExtractionService] Model $modelName is unavailable. Skipping to next candidate.');
              continue;
            }

            lastErrorMsg = sdkErrorStr;

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
                if (restResult.errorMessage!.contains('API_KEY_INVALID') ||
                    restResult.errorMessage!.contains('quota exceeded')) {
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
      }).timeout(
        const Duration(seconds: 90),
        onTimeout: () => ExtractedDocumentDetails.error(
          'Document analysis timed out after 90 seconds. Please retry.',
        ),
      );
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
        const Duration(seconds: 45),
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

        if (response.statusCode == 404 || errorMsg.contains('NOT_FOUND') || errorMsg.contains('no longer available')) {
          if (_cachedWorkingModel == modelName) _cachedWorkingModel = null;
          return ExtractedDocumentDetails.error('Model not found ($modelName): $errorMsg');
        } else if (response.statusCode == 429 || errorMsg.contains('RESOURCE_EXHAUSTED')) {
          errorMsg = 'Gemini API quota exceeded (Rate limit / 429). Will retry after cooldown.';
        } else if (errorMsg.contains('API_KEY_INVALID') || errorMsg.contains('API key not valid')) {
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

      // Extract text between first '{' and last '}' in case the model included surrounding commentary
      final firstBrace = cleanJson.indexOf('{');
      final lastBrace = cleanJson.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace >= firstBrace) {
        cleanJson = cleanJson.substring(firstBrace, lastBrace + 1).trim();
      }

      final dynamic decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) return null;

      final title = decoded['title'] as String?;
      var categoryStr = (decoded['category'] ?? decoded['documentType']) as String?;
      final expiryStr = (decoded['expiry_date'] ?? decoded['expiryDate']) as String?;
      final hiddenCtx = (decoded['hidden_context'] ?? decoded['hiddenContext']) as String?;
      final regNo = decoded['vehicleRegNo'] as String?;
      final policyNo = decoded['policyNo'] as String?;

      // Normalize category representation (e.g. "Photo", "Image", "Photograph" -> "photo")
      if (categoryStr != null && categoryStr.trim().isNotEmpty) {
        final catLower = categoryStr.trim().toLowerCase();
        if (catLower == 'photo' || catLower == 'image' || catLower == 'photograph' || catLower == 'picture') {
          categoryStr = 'photo';
        }
      }

      final isPhoto = categoryStr == 'photo' || categoryStr == 'image';

      Map<String, dynamic> visibleFields = {};

      // 1. Parse dynamic_visible_fields array: [{"label": "...", "value": "..."}]
      final dynFields = decoded['dynamic_visible_fields'];
      if (!isPhoto) {
        if (dynFields is List) {
          for (final item in dynFields) {
            if (item is Map) {
              final label = item['label']?.toString().trim();
              final value = item['value']?.toString().trim();
              if (label != null && label.isNotEmpty && value != null && value.isNotEmpty) {
                visibleFields[label] = value;
              }
            }
          }
        } else if (decoded['visibleFields'] is Map) {
          visibleFields = Map<String, dynamic>.from(decoded['visibleFields'] as Map);
        } else if (dynFields is Map) {
          visibleFields = Map<String, dynamic>.from(dynFields);
        }

        // Preserve legacy vehicle identifiers in visibleFields if present
        if (regNo != null && regNo.trim().isNotEmpty && regNo != 'null' && !visibleFields.containsKey('vehicleRegNo')) {
          visibleFields['vehicleRegNo'] = regNo.trim();
        }
        if (policyNo != null && policyNo.trim().isNotEmpty && policyNo != 'null' && !visibleFields.containsKey('policyNo')) {
          visibleFields['policyNo'] = policyNo.trim();
        }
      }

      // Automatically search dynamic fields for vehicle reg or policy numbers for backwards compatibility
      String? effectiveRegNo = (!isPhoto && regNo != null && regNo.trim().isNotEmpty && regNo != 'null') ? regNo.trim() : null;
      String? effectivePolicyNo = (!isPhoto && policyNo != null && policyNo.trim().isNotEmpty && policyNo != 'null') ? policyNo.trim() : null;

      if (!isPhoto && effectiveRegNo == null) {
        for (final entry in visibleFields.entries) {
          final lk = entry.key.toLowerCase();
          if (lk.contains('reg') || lk.contains('plate') || lk.contains('vehicle no')) {
            effectiveRegNo = entry.value.toString();
            break;
          }
        }
      }
      if (!isPhoto && effectivePolicyNo == null) {
        for (final entry in visibleFields.entries) {
          final lk = entry.key.toLowerCase();
          if (lk.contains('policy') || lk.contains('insurance no') || lk.contains('pnr')) {
            effectivePolicyNo = entry.value.toString();
            break;
          }
        }
      }

      // Resolve title: if this is a photo and title was omitted by AI, synthesize from hidden context
      String? effectiveTitle = (title != null && title.trim().isNotEmpty && title != 'null') ? title.trim() : null;
      if (effectiveTitle == null && (isPhoto || (categoryStr == null && hiddenCtx != null && hiddenCtx.trim().isNotEmpty))) {
        if (hiddenCtx != null && hiddenCtx.trim().isNotEmpty && hiddenCtx != 'null') {
          final firstSentence = hiddenCtx.split(RegExp(r'[\.\n]')).first.trim();
          effectiveTitle = (firstSentence.isNotEmpty && firstSentence.length <= 60)
              ? firstSentence
              : 'Photograph';
        } else {
          effectiveTitle = 'Photograph';
        }
        categoryStr ??= 'photo';
      }

      DocumentType? docType;
      if (categoryStr != null && categoryStr.isNotEmpty) {
        docType = DocumentType.fromString(categoryStr);
      }

      DateTime? expiryDate;
      if (!isPhoto && expiryStr != null && expiryStr.isNotEmpty) {
        try {
          expiryDate = DateTime.parse(expiryStr);
        } catch (_) {}
      }

      final details = ExtractedDocumentDetails(
        vehicleRegNo: effectiveRegNo,
        title: effectiveTitle,
        documentType: docType,
        category: categoryStr,
        policyNo: effectivePolicyNo,
        expiryDate: expiryDate,
        visibleFields: visibleFields,
        hiddenContext: (hiddenCtx != null && hiddenCtx.trim().isNotEmpty && hiddenCtx != 'null') ? hiddenCtx.trim() : null,
        isAiDetected: true,
        requiresAiScan: false,
        rawResponse: cleanJson,
      );

      return details.hasAnyDetail ? details : null;
    } catch (e) {
      developer.log('[GeminiExtractionService] Failed to parse JSON response: $rawText', error: e);
      return null;
    }
  }
}
