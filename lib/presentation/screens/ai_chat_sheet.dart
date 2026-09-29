import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_preferences_provider.dart';

import '../../data/datasources/remote/gemini_chat_service.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';
import 'document_viewer_screen.dart';

/// A chat message in the AI vault assistant conversation.
class _ChatMessage {
  final String text;
  final bool isUser;
  final List<VehicleDocument> referencedDocs;
  final bool isLoading;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.referencedDocs = const [],
    this.isLoading = false,
  });
}

/// Half-screen bottom sheet providing Gemini-powered conversational Q&A
/// over the user's entire document vault (e.g. "What's my TIN number?",
/// "When does my insurance expire?").
class AiChatSheet extends ConsumerStatefulWidget {
  const AiChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => const AiChatSheet(),
    );
  }

  @override
  ConsumerState<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends ConsumerState<AiChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, List<VehicleDocument> allDocs) async {
    final question = text.trim();
    if (question.isEmpty || _isTyping) return;

    _controller.clear();
    _focusNode.unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _messages.add(
          const _ChatMessage(text: '', isUser: false, isLoading: true));
      _isTyping = true;
    });
    _scrollToBottom();

    final apiKey = ref.read(geminiApiKeyProvider);
    final service = GeminiChatService(apiKey: apiKey);

    final answer = await service.ask(question: question, documents: allDocs);

    // Find referenced documents
    final referenced = allDocs
        .where((d) => answer.relevantDocumentIds.contains(d.id))
        .toList();

    if (mounted) {
      setState(() {
        _messages.removeLast(); // Remove loading bubble
        _messages.add(_ChatMessage(
          text: answer.answer,
          isUser: false,
          referencedDocs: referenced,
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docsAsync = ref.watch(vehicleDocumentsStreamProvider);
    final allDocs = docsAsync.value ?? [];

    final bgColor = isDark ? const Color(0xFF0C1338) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1D3DF0).withValues(alpha: 0.4) : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: isLiquidGlass
                  ? ImageFilter.blur(sigmaX: 30, sigmaY: 30)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: isLiquidGlass
                      ? (isDark
                          ? Colors.black.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.82))
                      : bgColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                    left: BorderSide(color: borderColor, width: 1),
                    right: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Vault Assistant',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Ask anything about your documents',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: isDark ? Colors.white54 : Colors.black45,
                                size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),

                    // Chat messages
                    Expanded(
                      child: _messages.isEmpty
                          ? _buildWelcome(isDark, allDocs)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                return _buildBubble(
                                    _messages[i], isDark, allDocs);
                              },
                            ),
                    ),

                    // Input field
                    _buildInput(isDark, allDocs),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcome(bool isDark, List<VehicleDocument> docs) {
    final suggestions = [
      'What\'s my TIN number?',
      'When does my insurance expire?',
      'Show me my ID details',
      'What is my driving license number?',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi! I can search through your ${docs.length} document${docs.length == 1 ? '' : 's'} and answer questions instantly.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Try asking:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    _controller.text = s;
                    _sendMessage(s, docs);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 14,
                            color: const Color(0xFF6366F1).withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: isDark ? Colors.white24 : Colors.black26),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBubble(
      _ChatMessage msg, bool isDark, List<VehicleDocument> docs) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Searching documents...',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              bottom: msg.referencedDocs.isEmpty ? 12 : 6,
              left: msg.isUser ? 60 : 0,
              right: msg.isUser ? 0 : 60,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: msg.isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    )
                  : null,
              color: msg.isUser
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    Radius.circular(msg.isUser ? 16 : 4),
                bottomRight:
                    Radius.circular(msg.isUser ? 4 : 16),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: msg.isUser
                    ? Colors.white
                    : (isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF1E293B)),
              ),
            ),
          ),
          // Referenced document chips
          if (msg.referencedDocs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referenced documents:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 5),
                  ...msg.referencedDocs.map((doc) => GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => DocumentViewerScreen(document: doc)),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(doc.documentType.icon,
                                  size: 14,
                                  color: const Color(0xFF6366F1)),
                              const SizedBox(width: 6),
                              Text(
                                doc.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new_rounded,
                                  size: 11, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isDark, List<VehicleDocument> docs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'Ask about your documents...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    border: InputBorder.none,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) => _sendMessage(v, docs),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isTyping ? null : () => _sendMessage(_controller.text, docs),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: _isTyping
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  color: _isTyping ? Colors.grey.withValues(alpha: 0.3) : null,
                  shape: BoxShape.circle,
                  boxShadow: _isTyping
                      ? []
                      : [
                          BoxShadow(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: Icon(
                  _isTyping
                      ? Icons.hourglass_empty_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
