# Strix AI — AI Chat Assistant Intern Assessment

Strix AI is a Flutter-based AI chat application developed for the **Mobile Application Engineering Internship Assessment**. It provides a local-first chat experience with configurable AI providers, conversation management, secure API-key storage, and persistent user settings.

## Assessment Scope

The project focuses on Flutter application architecture, state management with BLoC, local persistence, API integration, error handling, and maintainable code organization.

## Features

- **Conversation management:** Create, open, and delete conversations. New conversation titles are derived from the first prompt.
- **Local-first history:** Conversations and messages are saved locally and remain browsable offline.
- **Multiple AI providers:** Integrations for OpenAI, Google Gemini, Groq, Anthropic, and configurable OpenAI-compatible endpoints.
- **Custom provider configuration:** Set provider names, API base URLs, model names, enabled state, and API keys.
- **Retry handling:** Retry failed prompts with stable message identifiers to avoid duplicate local entries.
- **Chat experience:** Multiline input, timestamps, pending/error states, and response-progress indication.
- **Markdown rendering:** Render assistant responses using Markdown.
- **Theme preference:** Light and dark themes with persisted selection.

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter & Dart | Cross-platform mobile application |
| flutter_bloc / Bloc | State management |
| Drift & SQLite | Local persistence |
| Dio | HTTP networking |
| flutter_secure_storage | Secure API-key storage |
| GetIt | Dependency injection |
| Equatable | Value equality |
| flutter_markdown_plus | Markdown rendering |
| UUID | Stable message and entity identifiers |
| Mocktail | Test mocking |

## Architecture

The application is organized by feature and layer, separating presentation, domain logic, and data implementations.

```text
lib/
├── core/
│   ├── database/
│   ├── dependency injection/
│   └── shared utilities/
└── features/
    ├── chat/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── settings/
        ├── data/
        ├── domain/
        └── presentation/
```

The directory names above illustrate the high-level organization; consult the source tree for the exact paths.

### State Management

- **ConversationBloc:** Loads, creates, opens, and deletes conversations.
- **ChatBloc:** Loads chat history, manages sending and retrying messages, and coordinates local persistence with AI completion requests.
- **SettingsBloc:** Loads and updates provider configuration, the active provider, and the persisted theme preference.

The UI dispatches events and renders states. AI requests are abstracted behind repository contracts, keeping presentation and chat logic independent of individual provider request formats.

### Data Flow

1. A user message is persisted locally before the network request begins.
2. The selected provider adapter sends the request.
3. The response is persisted and presented in the conversation.
4. If the request fails, the message state is updated to allow retry.
5. Retries reuse stable identifiers to avoid duplicate local records.

## Persistence & Security

Drift manages a SQLite database in the application's documents directory. The database stores conversations, messages, provider configuration, and preferences.

- Conversations and messages are available offline.
- Conversation deletion also removes its associated messages through a foreign-key relationship.
- Stable message IDs and upsert operations support duplicate-safe retries.
- API keys are stored separately using `flutter_secure_storage`; they are not stored in the SQLite provider records or committed to source code.
- Sending messages requires an internet connection and a valid configured provider.

## Supported Providers

Provider settings are configurable from within the app. OpenAI and compatible services use a chat-completions style request, while Gemini uses its `generateContent` request format. The provider adapters also include Groq and Anthropic.

Provider model names, availability, and endpoint requirements may change. Users can configure the endpoint and model in Settings.

## Getting Started

### Prerequisites

- Flutter SDK and Dart SDK compatible with the versions specified in `pubspec.yaml`.
- Android SDK for Android builds (secure storage configuration requires a supported Android version).

### Run the application

Clone the repository and run:

```bash
flutter pub get
flutter run
```

### Configure an AI provider

1. Open **Settings**.
2. Add or select an AI provider.
3. Enter the provider's API key and required configuration (base URL and model, where applicable).
4. Save the configuration and start a conversation.

No API key or environment variable is bundled with the project.

## Bonus Features

The two bonus features implemented for the assessment are:

1. **Markdown rendering** for assistant messages.
2. **Persisted dark mode** preference.

## Testing & Verification

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

The tests cover provider request construction, local database persistence across reopening, retry idempotency, settings and API-key separation, and the dark-mode settings control.

**Reported verification status:** `flutter analyze` passed, and all 9 tests passed during the assessment verification run. Provider tests use mocked HTTP responses; live API calls and device-specific secure-storage behavior were not validated in that run.

## Limitations

- Responses are received as complete replies; token streaming is not implemented.
- Markdown rendering supports the renderer's supported Markdown features; embedded HTML is not rendered.
- The application calls AI providers directly from the client using the user's API key. There is no backend proxy, account system, or cross-device synchronization.
- Provider defaults may become outdated and can be changed from Settings.
- The SQLite schema is currently version 1; future schema changes require Drift migrations.

## AI Usage Disclosure

AI-assisted development details, tools, prompts, code contributions, engineering decisions, and verification notes are documented in [AI_USAGE.md](AI_USAGE.md).
