import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/chat_bloc.dart';
import '../blocs/conversation_bloc.dart';
import '../../domain/entities/conversation.dart';
import 'chat_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    context.read<ConversationBloc>().add(const ConversationsRequested());
  }

  Future<void> _createConversation() async {
    if (_creating) return;
    if (context.read<ChatBloc>().state.isSending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the current reply to finish.')),
      );
      return;
    }
    final bloc = context.read<ConversationBloc>();
    setState(() => _creating = true);
    final existingCount = bloc.state.conversations.length;
    final created = bloc.stream.firstWhere(
      (state) =>
          state is ConversationFailure ||
          (state.conversations.length > existingCount &&
              state.selected != null),
    );
    bloc.add(const ConversationCreated());
    try {
      final state = await created;
      if (!mounted) return;
      if (state is ConversationFailure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message)));
        return;
      }
      if (state.selected != null) _openConversation(state.selected!);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _openConversation(Conversation conversation) {
    if (context.read<ChatBloc>().state.isSending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the current reply to finish.')),
      );
      return;
    }
    context.read<ConversationBloc>().add(ConversationOpened(conversation));
    context.read<ChatBloc>().add(ChatMessagesRequested(conversation.id));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
  }

  Future<void> _deleteConversation(String id) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text('Its messages will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      context.read<ConversationBloc>().add(ConversationDeleted(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Strix AI',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<ConversationBloc, ConversationState>(
          builder: (context, state) {
            if (state is ConversationLoading && state.conversations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ConversationFailure) {
              return _MessageNotice(
                message: state.message,
                action: TextButton(
                  onPressed: () => context.read<ConversationBloc>().add(
                    const ConversationsRequested(),
                  ),
                  child: const Text('Try again'),
                ),
              );
            }
            if (state.conversations.isEmpty) {
              return _EmptyConversations(onCreate: _createConversation);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  child: Text(
                    'Your conversations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: state.conversations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final conversation = state.conversations[index];
                      return Card(
                        elevation: 0,
                        color: colors.surfaceContainerLow,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: colors.secondaryContainer,
                            foregroundColor: colors.onSecondaryContainer,
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                            ),
                          ),
                          title: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_dateLabel(conversation.updatedAt)),
                          onTap: () => _openConversation(conversation),
                          trailing: IconButton(
                            tooltip: 'Delete conversation',
                            onPressed: () =>
                                _deleteConversation(conversation.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createConversation,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New chat'),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today · ${TimeOfDay.fromDateTime(local).format(context)}';
    }
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({required this.onCreate});
  final VoidCallback onCreate;

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
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 38,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'A clear space for new ideas',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Start a chat with your preferred AI provider. Your history stays on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start a conversation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageNotice extends StatelessWidget {
  const _MessageNotice({required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 38),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
