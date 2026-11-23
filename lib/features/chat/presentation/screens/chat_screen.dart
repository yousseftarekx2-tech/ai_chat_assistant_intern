import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../settings/presentation/blocs/settings_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../blocs/chat_bloc.dart';
import '../blocs/conversation_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  String? _draftForMessageId;

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final settings = context.read<SettingsBloc>().state;
    final provider = settings.activeProvider;
    if (provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an AI provider in Settings first.'),
        ),
      );
      return;
    }
    if (!provider.isEnabled) return;
    final messageId = const Uuid().v4();
    _draftForMessageId = messageId;
    context.read<ChatBloc>().add(
      ChatMessageSent(
        conversation: widget.conversation,
        content: text,
        provider: provider,
        apiKey: provider.apiKey,
        messageId: messageId,
      ),
    );
  }

  void _retry(ChatMessage message) {
    final provider = context.read<SettingsBloc>().state.activeProvider;
    if (provider == null) return;
    _draftForMessageId = message.id;
    context.read<ChatBloc>().add(
      ChatRetryRequested(
        message: message,
        conversation: widget.conversation,
        provider: provider,
        apiKey: provider.apiKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.isSending && !current.isSending,
      listener: (context, state) {
        if (state.lastSentMessageId == _draftForMessageId &&
            _composer.text.trim().isNotEmpty) {
          _composer.clear();
          _draftForMessageId = null;
        }
        context.read<ConversationBloc>().add(const ConversationsRequested());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
            );
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Private on this device',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, state) {
                    if (state.isLoading && state.messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.messages.isEmpty && state.error == null) {
                      return _ChatWelcome(
                        providerName: context.select<SettingsBloc, String?>(
                          (bloc) => bloc.state.activeProvider?.name,
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      itemCount:
                          state.messages.length + (state.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (state.isSending && index == 0) {
                          return const _TypingIndicator();
                        }
                        final messageIndex =
                            state.messages.length -
                            1 -
                            (state.isSending ? index - 1 : index);
                        return _MessageBubble(
                          message: state.messages[messageIndex],
                          onRetry: _retry,
                          isSending: state.isSending,
                        );
                      },
                    );
                  },
                ),
              ),
              BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (oldState, newState) =>
                    oldState.error != newState.error,
                builder: (context, state) => state.error == null
                    ? const SizedBox.shrink()
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: colors.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (oldState, newState) =>
                    oldState.isSending != newState.isSending ||
                    oldState.isLoading != newState.isLoading,
                builder: (context, state) => _Composer(
                  controller: _composer,
                  isSending: state.isSending || state.isLoading,
                  onSend: _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome({required this.providerName});
  final String? providerName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.onPrimaryContainer,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'What would you like to explore?',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              providerName == null
                  ? 'Configure an AI provider in Settings to begin.'
                  : 'Your message will be sent to $providerName.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 6, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message Strix AI',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) {
                    if (!isSending) onSend();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: IconButton.filled(
                  tooltip: isSending ? 'Waiting for response' : 'Send message',
                  onPressed: isSending ? null : onSend,
                  icon: isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onRetry,
    required this.isSending,
  });
  final ChatMessage message;
  final ValueChanged<ChatMessage> onRetry;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.role == MessageRole.user;
    final background = isUser
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final foreground = isUser ? colors.onPrimaryContainer : colors.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .84,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(15, 11, 15, 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUser)
                SelectableText(
                  message.content,
                  style: TextStyle(color: foreground, height: 1.4),
                )
              else
                MarkdownBody(
                  data: message.content,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: TextStyle(color: foreground, height: 1.45),
                        code: TextStyle(
                          color: foreground,
                          fontFamily: 'monospace',
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    TimeOfDay.fromDateTime(
                      message.createdAt.toLocal(),
                    ).format(context),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: .68),
                    ),
                  ),
                  if (isUser &&
                      message.status == MessageStatus.pending &&
                      isSending) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: foreground.withValues(alpha: .7),
                    ),
                  ],
                  if (isUser &&
                      !isSending &&
                      (message.status == MessageStatus.failed ||
                          message.status == MessageStatus.pending)) ...[
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => onRetry(message),
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Thinking…', style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
