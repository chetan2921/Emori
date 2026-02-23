import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/entry_provider.dart';
import '../history/history_screen.dart';
import '../insights/pattern_detection_screen.dart';
import '../insights/weekly_reflection_screen.dart';
import '../reminders/reminders_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _wasLastInputFromMic = false;
  final List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    // Explicitly request microphone and speech permissions
    await [Permission.microphone, Permission.speech].request();
  }

  Future<void> _toggleListening() async {
    await _requestPermissions();

    if (!_speechAvailable) {
      // Try initializing again in case permissions were just granted
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Speech recognition is not available or permissions were denied.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: AppColors.coral,
            ),
          );
        }
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      // Stop any ongoing TTS so user can speak
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.stop();

      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _wasLastInputFromMic = true;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });

          // Auto-send when speech recognition finalizes
          if (result.finalResult && _controller.text.trim().isNotEmpty) {
            setState(() => _isListening = false);
            _sendMessage();
          }
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    }
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) return;

    final bool speakResponse = _wasLastInputFromMic;

    _controller.clear();
    _wasLastInputFromMic = false; // reset for next message

    final images = List<File>.from(_selectedImages);
    setState(() => _selectedImages.clear());
    _scrollToBottom();

    await ref
        .read(chatProvider.notifier)
        .sendMessage(text, images: images, speakResponse: speakResponse);
    _scrollToBottom();
  }

  void _showImagePicker() {
    final c = context.colors;
    final imageService = ref.read(imageServiceProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.textHint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add a photo',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _PickerOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final file = await imageService.takePhoto();
                      if (file != null && mounted) {
                        setState(() => _selectedImages.add(file));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final file = await imageService.pickFromGallery();
                      if (file != null && mounted) {
                        setState(() => _selectedImages.add(file));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider);
    final c = context.colors;
    ref.listen(chatProvider, (prev, next) => _scrollToBottom());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.background,
      drawer: _buildDrawer(c),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Builder(
              builder: (ctx) {
                final hasMessages =
                    messagesAsync.hasValue && messagesAsync.value!.isNotEmpty;
                return _buildHeader(ctx, c, hasMessages: hasMessages);
              },
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return _buildEmptyState(c);
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) =>
                        _MessageBubble(message: messages[i])
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 300.ms,
                              curve: Curves.easeOut,
                            ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
            if (messagesAsync.hasValue && messagesAsync.value!.isEmpty)
              _buildSuggestions(c),
            _buildInput(c),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(EmoriColors c) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Hey, I'm ",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: c.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: 'Emori',
                        style: TextStyle(
                          fontFamily: 'AlexBrush',
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                )
                .animate(delay: 100.ms)
                .slideY(
                  begin: 0.2,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                )
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            const _RotatingText()
                .animate(delay: 200.ms)
                .slideY(
                  begin: 0.2,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                )
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            Text(
                  "I remember everything you've shared with me. Ask me anything about your life — your patterns, your feelings, what you've been going through. I'm here.",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: c.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate(delay: 300.ms)
                .slideY(
                  begin: 0.2,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                )
                .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(EmoriColors c) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? '';
    final userName = userEmail.isNotEmpty ? userEmail.split('@')[0] : 'User';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: c.surface,
      child: SafeArea(
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        userName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textHint),
                  ],
                ),
              ),
            ),
            const Divider(),
            _DrawerItem(
              icon: Icons.add_comment_outlined,
              label: 'New Chat',
              onTap: () {
                Navigator.pop(context);
                ref.read(chatProvider.notifier).clearChat();
              },
            ),
            _DrawerItem(
              icon: Icons.hub_outlined,
              label: 'Pattern Detection',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PatternDetectionScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.notifications_outlined,
              label: 'Reminders',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemindersScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.nights_stay_outlined,
              label: 'Weekly Reflections',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WeeklyReflectionScreen(),
                  ),
                );
              },
            ),
            const Spacer(),
            _DrawerItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    EmoriColors c, {
    bool hasMessages = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: c.textPrimary),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
          // Emori title only appears when chat has started
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  ),
                );
              },
              child: hasMessages
                  ? Text(
                      'Emori',
                      key: const ValueKey('emori-header'),
                      style: TextStyle(
                        fontFamily: 'AlexBrush',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty-header')),
            ),
          ),
          IconButton(
            icon: Icon(Icons.auto_stories_outlined, color: c.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(EmoriColors c) {
    final suggestions = [
      'What have I been stressed about?',
      'What patterns do you see in me?',
      'How have I been feeling lately?',
      'What do I keep struggling with?',
    ];
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (ctx, i) =>
            GestureDetector(
                  onTap: () {
                    _controller.text = suggestions[i];
                    _sendMessage();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.olive.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      suggestions[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                )
                .animate(delay: (i * 100).ms)
                .fadeIn(duration: 400.ms)
                .slideX(begin: 0.2, end: 0, duration: 400.ms),
      ),
    );
  }

  Widget _buildInput(EmoriColors c) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Image previews (inside the input area) ──────
          if (_selectedImages.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border, width: 1),
                          image: DecorationImage(
                            image: FileImage(_selectedImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: c.textSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // ─── Input row ───────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image button
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Mic button
              GestureDetector(
                onTap: _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppColors.coral
                        : AppColors.sage.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isListening
                        ? [AppShadows.colored(AppColors.coral)]
                        : [],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isListening ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: c.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share anything...',
                      hintStyle: GoogleFonts.inter(
                        color: c.textHint,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      if (_wasLastInputFromMic) {
                        setState(() {
                          _wasLastInputFromMic = false;
                        });
                      }
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isThinking = message.text == '...';
    final c = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 10,
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'E',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : c.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isThinking
                  ? const _ThinkingDots()
                  : Text(
                      message.text,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: isUser ? Colors.white : c.textPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.sage.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotatingText extends StatefulWidget {
  const _RotatingText();

  @override
  State<_RotatingText> createState() => _RotatingTextState();
}

class _RotatingTextState extends State<_RotatingText> {
  int _currentIndex = 0;
  final List<Map<String, String>> _phrases = [
    {'highlight': 'Ask', 'suffix': ' me anything'},
    {'highlight': 'Vent', 'suffix': ' without judgement'},
    {'highlight': 'Gossip', 'suffix': ' like a bestie'},
    {'highlight': 'Reflect', 'suffix': ' on your day'},
    {'highlight': 'Discover', 'suffix': ' your patterns'},
    {'highlight': 'Chat', 'suffix': ' as a friend'},
    {'highlight': 'Unload', 'suffix': ' what\'s heavy'},
    {'highlight': 'Remember', 'suffix': ' everything'},
    {'highlight': 'Track', 'suffix': ' your emotions'},
    {'highlight': 'Explore', 'suffix': ' your thoughts'},
    {'highlight': 'Share', 'suffix': ' your wins'},
    {'highlight': 'Process', 'suffix': ' the hard stuff'},
  ];

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  void _startRotation() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _phrases.length;
      });
      _startRotation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phrase = _phrases[_currentIndex];

    return SizedBox(
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.4),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: RichText(
          key: ValueKey<int>(_currentIndex),
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: phrase['highlight']!,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              TextSpan(
                text: phrase['suffix']!,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
