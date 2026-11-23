import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../settings/domain/entities/ai_provider_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_chat_message.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

final class ChatMessagesRequested extends ChatEvent {
  const ChatMessagesRequested(this.conversationId);
  final String conversationId;
  @override
  List<Object?> get props => [conversationId];
}

base class ChatMessageSent extends ChatEvent {
  const ChatMessageSent({
    required this.conversation,
    required this.content,
    required this.provider,
    required this.apiKey,
    this.messageId,
  });

  final Conversation conversation;
  final String content;
  final AiProviderConfig provider;
  final String apiKey;

  /// Pass the same ID when retrying a failed message.
  final String? messageId;

  @override
  List<Object?> get props => [
    conversation,
    content,
    provider,
    apiKey,
    messageId,
  ];
}

final class ChatRetryRequested extends ChatMessageSent {
  ChatRetryRequested({
    required this.message,
    required super.conversation,
    required super.provider,
    required super.apiKey,
  }) : super(content: message.content, messageId: message.id);
  final ChatMessage message;

  @override
  List<Object?> get props => [...super.props, message];
}

class ChatState extends Equatable {
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.lastSentMessageId,
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? lastSentMessageId;

  ChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
    String? lastSentMessageId,
  }) => ChatState(
    conversationId: conversationId ?? this.conversationId,
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    error: clearError ? null : error ?? this.error,
    lastSentMessageId: lastSentMessageId ?? this.lastSentMessageId,
  );

  @override
  List<Object?> get props => [
    conversationId,
    messages,
    isLoading,
    isSending,
    error,
    lastSentMessageId,
  ];
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._chat, this._sendMessage, {this._uuid = const Uuid()})
    : super(const ChatState()) {
    on<ChatMessagesRequested>(_loadMessages);
    on<ChatMessageSent>(_send, transformer: droppable());
  }

  final ChatRepository _chat;
  final SendChatMessage _sendMessage;
  final Uuid _uuid;

  Future<void> _loadMessages(
    ChatMessagesRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state.isSending) return;
    emit(
      state.copyWith(
        conversationId: event.conversationId,
        isLoading: true,
        isSending: false,
        clearError: true,
      ),
    );
    try {
      final messages = await _chat.getMessages(event.conversationId);
      emit(state.copyWith(messages: messages, isLoading: false));
    } on Exception catch (error) {
      emit(
        state.copyWith(isLoading: false, error: 'Could not load chat: $error'),
      );
    }
  }

  Future<void> _send(ChatMessageSent event, Emitter<ChatState> emit) =>
      _sendContent(
        conversation: event.conversation,
        content: event.content,
        provider: event.provider,
        apiKey: event.apiKey,
        messageId: event.messageId ?? _uuid.v4(),
        emit: emit,
      );

  Future<void> _sendContent({
    required Conversation conversation,
    required String content,
    required AiProviderConfig provider,
    required String apiKey,
    required String messageId,
    required Emitter<ChatState> emit,
  }) async {
    if (state.isSending || state.isLoading || content.trim().isEmpty) return;
    emit(
      state.copyWith(
        conversationId: conversation.id,
        isSending: true,
        clearError: true,
        lastSentMessageId: null,
      ),
    );
    late final List<ChatMessage> current;
    try {
      current = await _chat.getMessages(conversation.id);
    } on Exception catch (error) {
      emit(
        state.copyWith(isSending: false, error: 'Could not load chat: $error'),
      );
      return;
    }
    final existing = current.where((message) => message.id == messageId);
    final createdAt = existing.isEmpty
        ? DateTime.now()
        : existing.first.createdAt;
    final userMessage = ChatMessage(
      id: messageId,
      conversationId: conversation.id,
      role: MessageRole.user,
      content: content.trim(),
      createdAt: createdAt,
      providerId: provider.id,
      status: MessageStatus.pending,
    );
    final pendingMessages = _upsert(current, userMessage);
    emit(state.copyWith(messages: pendingMessages));

    try {
      await _chat.saveConversation(
        Conversation(
          id: conversation.id,
          title: conversation.title == 'New conversation'
              ? _conversationTitle(content)
              : conversation.title,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          providerId: provider.id,
        ),
      );
      await _chat.saveMessage(userMessage);

      final response = StringBuffer();
      await for (final chunk in _sendMessage(
        provider: provider,
        apiKey: apiKey,
        history: pendingMessages,
      )) {
        response.write(chunk);
      }

      final sentUser = userMessage.copyWith(status: MessageStatus.sent);
      final assistant = ChatMessage(
        id: 'assistant_$messageId',
        conversationId: conversation.id,
        role: MessageRole.assistant,
        content: response.toString(),
        createdAt: DateTime.now(),
        providerId: provider.id,
      );
      await _chat.saveMessage(sentUser);
      await _chat.saveMessage(assistant);
      emit(
        state.copyWith(
          messages: _upsert(_upsert(pendingMessages, sentUser), assistant),
          isSending: false,
          lastSentMessageId: messageId,
        ),
      );
    } on Exception catch (error) {
      final failed = userMessage.copyWith(status: MessageStatus.failed);
      var failure = error.toString();
      try {
        await _chat.saveMessage(failed);
      } on Exception catch (storageError) {
        failure = 'Could not save failed message: $storageError';
      }
      emit(
        state.copyWith(
          messages: _upsert(pendingMessages, failed),
          isSending: false,
          error: failure,
        ),
      );
    }
  }

  List<ChatMessage> _upsert(List<ChatMessage> messages, ChatMessage message) {
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index == -1) return [...messages, message];
    final updated = [...messages];
    updated[index] = message;
    return updated;
  }

  String _conversationTitle(String prompt) {
    final normalized = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 48) return normalized;
    return '${normalized.substring(0, 45)}…';
  }
}
