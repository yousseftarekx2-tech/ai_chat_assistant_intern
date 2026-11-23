# Strix AI

Strix AI is a Flutter chat application for talking to configurable AI providers. Conversations and messages are stored on the device and remain available when the network is unavailable.

## Setup

Requirements: Flutter SDK and Dart SDK versions compatible with `pubspec.yaml`. Android builds require API 23 or newer for secure API-key storage.

```bash
flutter pub get
flutter run
```

## Environment variables

The app does not require environment variables or bundled API keys. Add a provider and its API key from **Settings**. Keys are written to platform secure storage; provider names, URLs, models, active-provider selection, and theme preference are stored in the local Drift database.

## Features

- Create, open, and delete conversations; new conversation titles use the first prompt.
- Read saved conversations and messages offline.
- Send multiline prompts to OpenAI, Google Gemini, or a configurable OpenAI-compatible endpoint.
- Configure provider name, API base URL, model, enabled state, and API key. Groq and Anthropic adapters are also included.
- Retry failed prompts using their original message IDs, preventing duplicate local messages.
- See timestamps, pending/error states, and a response-in-progress indicator.
- Render assistant Markdown and switch between light and dark themes.

## Architecture

The code is organized by feature and layer:

- `lib/core/`: Drift database, dependency registration, and shared exceptions.
- `lib/features/chat/domain/`: conversation/message entities, repository contracts, and use cases.
- `lib/features/chat/data/`: Drift conversation persistence and Dio provider adapters.
- `lib/features/chat/presentation/`: `ConversationBloc`, `ChatBloc`, screens, and chat widgets.
- `lib/features/settings/`: provider settings contract, Drift/Secure Storage implementation, `SettingsBloc`, and settings screen.

### Bloc flow

- `ConversationBloc` loads, creates, opens, and deletes conversations.
- `ChatBloc` loads message history, stores a pending user message locally before making a network request, then stores the response. Failed messages keep their stable IDs for retry.
- `SettingsBloc` loads and saves provider configuration, the active provider, and dark-mode preference.

Widgets dispatch events and render Bloc states. Provider calls are made through `AiCompletionRepository`, so chat logic does not depend on an individual provider's HTTP format.

## Local storage and offline use

Drift opens a SQLite database in the application's documents directory. It contains `conversations`, `messages`, `providers`, and `preferences` tables. A foreign key removes a conversation's messages when it is deleted. Message IDs are unique and writes use an upsert, which makes retrying a failed prompt idempotent in local storage.

Previous conversations can be browsed without a network connection. Sending a prompt still requires a reachable provider. API keys are stored separately through `flutter_secure_storage` and are not placed in the SQLite provider table or source code.

## Providers

The default entries are editable in Settings. OpenAI and compatible endpoints use the chat-completions request format. Gemini uses its `generateContent` format. For a custom compatible service, enter the base URL expected by that service, its model name, and its API key. Model availability and endpoint requirements are determined by the provider account.

## Verification

```bash
flutter analyze
flutter test
```

The test suite covers provider request formats, database persistence across a reopen, duplicate-safe retries, provider settings and key separation, and the settings screen's dark-mode control.

## Known limitations

- Responses are delivered as complete API replies; token streaming is not implemented.
- Markdown output supports the renderer's GitHub Flavored Markdown features; embedded HTML is not rendered.
- The app calls providers directly from the client using the user's own API key. It does not include a backend proxy, account system, or cross-device synchronization.
- Provider defaults are starting points and can become outdated; users can update the URL and model in Settings.
- The current SQLite schema is version 1. Future schema changes must add and test a Drift migration before release.
- Provider integrations are covered with mocked HTTP tests; live API calls and device-specific secure-storage behavior were not tested in this environment.

See [AI_USAGE.md](AI_USAGE.md) for the required AI-use disclosure.
