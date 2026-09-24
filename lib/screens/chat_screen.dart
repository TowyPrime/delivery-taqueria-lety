import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/config/chat_bot_config.dart';
import 'package:delivery_app/models/chat_message.dart';
import 'package:delivery_app/providers/auth_provider.dart';
import 'package:delivery_app/providers/order_provider.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/services/chat_bot.dart';
import 'package:delivery_app/services/claim_service.dart';
import 'package:delivery_app/services/whatsapp_service.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  /// [bot], [openWhatsApp] y [replyDelay] se pueden sustituir (p. ej. en tests).
  const ChatScreen({
    super.key,
    this.bot,
    this.openWhatsApp,
    this.replyDelay = const Duration(milliseconds: 700),
  });

  final ChatBot? bot;
  final Future<bool> Function()? openWhatsApp;
  final Duration replyDelay;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _QuickReply {
  final IconData icon;
  final String label;
  final BotIntent intent;

  const _QuickReply(this.icon, this.label, this.intent);
}

const _quickReplies = [
  _QuickReply(
    Icons.assignment_return_outlined,
    ChatBotConfig.quickReturns,
    BotIntent.returns,
  ),
  _QuickReply(
    Icons.receipt_long_outlined,
    ChatBotConfig.quickActiveOrders,
    BotIntent.activeOrders,
  ),
  _QuickReply(
    Icons.report_problem_outlined,
    ChatBotConfig.quickClaims,
    BotIntent.claims,
  ),
  _QuickReply(
    Icons.support_agent_rounded,
    ChatBotConfig.quickAdvisor,
    BotIntent.advisor,
  ),
];

class _ChatScreenState extends State<ChatScreen> {
  late final ChatBot _bot;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [
    const ChatMessage(text: ChatBotConfig.welcome, fromBot: true),
  ];
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _bot = widget.bot ?? _defaultBot();
  }

  ChatBot _defaultBot() {
    final auth = context.read<AppAuthProvider>();
    final orders = context.read<OrderProvider>();
    final claims = context.read<ClaimService>();
    return ChatBot(
      isLoggedIn: () => !auth.needsLogin,
      loadActiveOrders: () => orders.fetchActiveOrders(auth.currentUserId ?? ''),
      loadClaims: () => claims.fetchUserClaims(auth.currentUserId ?? ''),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Envía [text] como mensaje del usuario y responde el bot. Si se conoce la
  /// intención (respuesta rápida) se usa directo; si no, se detecta del texto.
  Future<void> _ask(String text, {BotIntent? intent}) async {
    final clean = text.trim();
    if (clean.isEmpty || _typing) return;

    setState(() {
      _messages.add(ChatMessage(text: clean, fromBot: false));
      _typing = true;
    });
    _controller.clear();
    _scrollToEnd();

    List<ChatMessage> replies;
    try {
      await Future<void>.delayed(widget.replyDelay);
      replies = intent != null
          ? await _bot.respondTo(intent)
          : await _bot.respondToText(clean);
    } catch (_) {
      replies = const [
        ChatMessage(text: ChatBotConfig.fallback, fromBot: true),
      ];
    }

    if (!mounted) return;
    setState(() {
      _messages.addAll(replies);
      _typing = false;
    });
    _scrollToEnd();
  }

  Future<void> _runAction(BotAction action) async {
    switch (action) {
      case BotAction.openWhatsApp:
        final ok = await (widget.openWhatsApp ?? openBusinessWhatsApp)();
        if (!ok && mounted) {
          showAppSnackBar(
            context,
            ChatBotConfig.whatsappOpenError,
            kind: SnackKind.error,
          );
        }
      case BotAction.goToLogin:
        goToLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 34),
            SizedBox(width: 10),
            Text(ChatBotConfig.botName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingBubble();
                return _Bubble(message: _messages[index], onAction: _runAction);
              },
            ),
          ),

          // Respuestas rápidas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (final q in _quickReplies) ...[
                  ActionChip(
                    avatar: Icon(q.icon, size: 18, color: AppColors.primary),
                    label: Text(q.label),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: const StadiumBorder(),
                    onPressed: _typing
                        ? null
                        : () => _ask(q.label, intent: q.intent),
                  ),
                  if (q != _quickReplies.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Campo de texto
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (value) => _ask(value),
                        decoration: const InputDecoration(
                          hintText: 'Escribe tu mensaje',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Enviar',
                      onPressed: _typing ? null : () => _ask(_controller.text),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(BotAction action) onAction;

  const _Bubble({required this.message, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final fromBot = message.fromBot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: fromBot ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: fromBot ? AppColors.surface : AppColors.primary,
            border: fromBot ? Border.all(color: AppColors.border) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(fromBot ? 4 : 18),
              bottomRight: Radius.circular(fromBot ? 18 : 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: fromBot ? AppColors.ink : Colors.white,
                ),
              ),
              for (final action in message.actions) ...[
                const SizedBox(height: 12),
                _ActionButton(action: action, onPressed: () => onAction(action)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final BotAction action;
  final VoidCallback onPressed;

  const _ActionButton({required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isWhatsapp = action == BotAction.openWhatsApp;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isWhatsapp ? Icons.chat_rounded : Icons.login_rounded,
        size: 20,
      ),
      label: Text(
        isWhatsapp ? ChatBotConfig.buttonWhatsapp : ChatBotConfig.buttonLogin,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: isWhatsapp ? AppColors.success : AppColors.primary,
        minimumSize: const Size.fromHeight(46),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: const Text(
            'Escribiendo…',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
