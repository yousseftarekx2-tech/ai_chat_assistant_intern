# AI Usage Report

This report discloses AI assistance used to implement the Strix AI assessment project. Review and revise it if additional contributors make changes before submission.

## AI tools used

- OpenAI Codex coding agent (GPT-6) in the Codex desktop app.
- The agent used web search to verify Gemini's `generateContent` request format, Drift's migration guidance, Android's network-permission requirement, the Android minimum for `flutter_secure_storage`, and Groq model deprecations. These references informed the current integrations and configuration.

## Prompts used

The applicant asked the agent to:

1. Inspect the current Flutter project and begin the Strix assessment implementation from the agreed requirements.
2. Continue the project against the attached **Mobile Application Engineering Internship Assessment**, with priorities covering Drift persistence, repository/data-source implementations, `ChatBloc` / `ConversationBloc` / `SettingsBloc`, OpenAI/Gemini/OpenAI-compatible APIs, retry-safe local-first sends, conversation/chat/settings screens, Markdown, dark mode, and secure API-key storage.
3. Run `flutter analyze` and relevant tests after each implementation stage, fix issues before continuing, and create `README.md` and this `AI_USAGE.md` with a truthful completion status.

## AI-generated or AI-assisted code

Codex drafted and revised the implementation in `lib/`, including:

- Drift database schema and repositories for chats and provider settings.
- Dio adapters for OpenAI-compatible endpoints, Gemini, Groq, and Anthropic.
- Domain entities and repository contracts.
- The three Blocs, dependency registration, conversation/chat/settings screens, Markdown rendering, and theme switching.
- Unit and widget tests under `test/`.
- Project documentation.

The applicant supplied the assessment requirements and requested the implementation. No applicant-authored source snippet was included in this coding session. AI-generated code should be reviewed and understood by the applicant before submission or interview discussion.

## Manually written code

No code was manually transcribed by the applicant in this session. The requirements, acceptance priorities, and requests to verify behavior were provided by the applicant. Update this section if the applicant or another contributor manually edits code before delivery.

## Engineering decisions

- Drift manages the SQLite connection and migrations; explicit SQL statements are used for the small schema to avoid adding a code-generation toolchain to this project.
- API keys are kept in platform secure storage; provider metadata and preferences use SQLite.
- Sending is gated while a request is active. A stable user-message ID and deterministic assistant-message ID make retries safe from local duplicates.
- The two implemented bonus features are Markdown rendering and persisted dark mode. Streaming responses and conversation search were not selected.
- Tests use fake AI responses and local databases. They do not contact paid or live provider APIs.

## Verification performed

- `flutter analyze` — passed with no issues.
- `flutter test` — passed all 9 tests, covering OpenAI-compatible/Gemini request construction, offline database persistence, retry idempotency including recovery of an interrupted pending message, secure-key separation, provider preferences, and the dark-mode settings control.
