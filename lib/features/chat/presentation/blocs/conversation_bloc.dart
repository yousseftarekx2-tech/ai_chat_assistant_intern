import 'package:equatable/equatable.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/load_conversations.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();
  @override
  List<Object?> get props => [];
}

final class ConversationsRequested extends ConversationEvent {
  const ConversationsRequested();
}

final class ConversationCreated extends ConversationEvent {
  const ConversationCreated({this.title = 'New conversation'});
  final String title;
  @override
  List<Object?> get props => [title];
}

final class ConversationDeleted extends ConversationEvent {
  const ConversationDeleted(this.conversationId);
  final String conversationId;
  @override
  List<Object?> get props => [conversationId];
}

final class ConversationOpened extends ConversationEvent {
  const ConversationOpened(this.conversation);
  final Conversation conversation;
  @override
  List<Object?> get props => [conversation];
}

sealed class ConversationState extends Equatable {
  const ConversationState({this.conversations = const [], this.selected});
  final List<Conversation> conversations;
  final Conversation? selected;
  @override
  List<Object?> get props => [conversations, selected];
}

final class ConversationInitial extends ConversationState {
  const ConversationInitial();
}

final class ConversationLoading extends ConversationState {
  const ConversationLoading({super.conversations, super.selected});
}

final class ConversationEmpty extends ConversationState {
  const ConversationEmpty();
}

final class ConversationLoaded extends ConversationState {
  const ConversationLoaded({required super.conversations, super.selected});
}

final class ConversationFailure extends ConversationState {
  const ConversationFailure(
    this.message, {
    super.conversations,
    super.selected,
  });
  final String message;
  @override
  List<Object?> get props => [...super.props, message];
}

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc(ChatRepository repository, {this._uuid = const Uuid()})
    : _repository = repository,
      _loadConversations = LoadConversations(repository),
      super(const ConversationInitial()) {
    on<ConversationsRequested>(_load, transformer: sequential());
    on<ConversationCreated>(_create, transformer: sequential());
    on<ConversationDeleted>(_delete, transformer: sequential());
    on<ConversationOpened>(_open, transformer: sequential());
  }

  final ChatRepository _repository;
  final LoadConversations _loadConversations;
  final Uuid _uuid;

  Future<void> _load(
    ConversationsRequested event,
    Emitter<ConversationState> emit,
  ) async {
    emit(
      ConversationLoading(
        conversations: state.conversations,
        selected: state.selected,
      ),
    );
    try {
      final conversations = await _loadConversations();
      emit(
        conversations.isEmpty
            ? const ConversationEmpty()
            : ConversationLoaded(
                conversations: conversations,
                selected: _selectedFrom(conversations),
              ),
      );
    } on Exception catch (error) {
      emit(
        ConversationFailure(
          'Could not load conversations: $error',
          conversations: state.conversations,
          selected: state.selected,
        ),
      );
    }
  }

  Future<void> _create(
    ConversationCreated event,
    Emitter<ConversationState> emit,
  ) async {
    final now = DateTime.now();
    final conversation = Conversation(
      id: _uuid.v4(),
      title: event.title.trim().isEmpty
          ? 'New conversation'
          : event.title.trim(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _repository.saveConversation(conversation);
      final conversations = [conversation, ...state.conversations];
      emit(
        ConversationLoaded(
          conversations: conversations,
          selected: conversation,
        ),
      );
    } on Exception catch (error) {
      emit(
        ConversationFailure(
          'Could not create conversation: $error',
          conversations: state.conversations,
          selected: state.selected,
        ),
      );
    }
  }

  Future<void> _delete(
    ConversationDeleted event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      await _repository.deleteConversation(event.conversationId);
      final conversations = state.conversations
          .where((item) => item.id != event.conversationId)
          .toList(growable: false);
      final selected = state.selected?.id == event.conversationId
          ? null
          : state.selected;
      emit(
        conversations.isEmpty
            ? const ConversationEmpty()
            : ConversationLoaded(
                conversations: conversations,
                selected: selected,
              ),
      );
    } on Exception catch (error) {
      emit(
        ConversationFailure(
          'Could not delete conversation: $error',
          conversations: state.conversations,
          selected: state.selected,
        ),
      );
    }
  }

  void _open(ConversationOpened event, Emitter<ConversationState> emit) {
    emit(
      ConversationLoaded(
        conversations: state.conversations,
        selected: event.conversation,
      ),
    );
  }

  Conversation? _selectedFrom(List<Conversation> conversations) {
    final id = state.selected?.id;
    if (id == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }
}
