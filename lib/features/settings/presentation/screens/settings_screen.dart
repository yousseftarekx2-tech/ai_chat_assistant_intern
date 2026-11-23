import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/ai_provider_config.dart';
import '../blocs/settings_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.isLoading && state.providers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final colors = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                child: SwitchListTile.adaptive(
                  value: state.darkModeEnabled,
                  onChanged: (value) =>
                      context.read<SettingsBloc>().add(DarkModeChanged(value)),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text(
                    'Use a darker color scheme throughout the app.',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI providers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _editProvider(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'API keys are stored securely on this device. Provider URLs and model names are saved locally.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ...state.providers.map(
                (provider) => Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  child: ListTile(
                    selected: state.activeProviderId == provider.id,
                    onTap: provider.isEnabled
                        ? () {
                            context.read<SettingsBloc>().add(
                              ActiveProviderChanged(provider.id),
                            );
                          }
                        : null,
                    leading: Icon(
                      state.activeProviderId == provider.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit provider',
                          onPressed: () => _editProvider(context, provider),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${provider.model} · ${provider.apiKey.isEmpty ? 'API key needed' : 'API key saved'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(state.error!, style: TextStyle(color: colors.error)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editProvider(
    BuildContext context, [
    AiProviderConfig? provider,
  ]) async {
    final result = await showDialog<AiProviderConfig>(
      context: context,
      builder: (_) => _ProviderEditorDialog(provider: provider),
    );
    if (result != null && context.mounted) {
      context.read<SettingsBloc>().add(ProviderSaved(result));
    }
  }
}

class _ProviderEditorDialog extends StatefulWidget {
  const _ProviderEditorDialog({this.provider});
  final AiProviderConfig? provider;

  @override
  State<_ProviderEditorDialog> createState() => _ProviderEditorDialogState();
}

class _ProviderEditorDialogState extends State<_ProviderEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late AiProviderType _type;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _name = TextEditingController(text: provider?.name ?? 'My AI provider');
    _baseUrl = TextEditingController(
      text: provider?.baseUrl.toString() ?? 'https://api.example.com/v1',
    );
    _model = TextEditingController(text: provider?.model ?? 'model-name');
    _apiKey = TextEditingController();
    _type = provider?.type ?? AiProviderType.openAiCompatible;
    _enabled = provider?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.provider == null ? 'Add provider' : 'Edit provider'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Provider name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AiProviderType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Provider type'),
                  items: AiProviderType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _baseUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.example.com/v1',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    if (uri == null ||
                        !uri.hasAuthority ||
                        !{'https', 'http'}.contains(uri.scheme)) {
                      return 'Enter a valid http or https URL.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Model name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKey,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.provider?.apiKey.isNotEmpty == true
                        ? 'API key (saved; leave blank to keep it)'
                        : 'API key',
                    helperText: 'Stored in platform secure storage.',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('Enabled'),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.provider != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SettingsBloc>().add(
                ProviderRemoved(widget.provider!.id),
              );
            },
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save provider')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.provider;
    Navigator.pop(
      context,
      AiProviderConfig(
        id: existing?.id ?? 'custom-${const Uuid().v4()}',
        name: _name.text.trim(),
        type: _type,
        baseUrl: Uri.parse(_baseUrl.text.trim()),
        model: _model.text.trim(),
        isEnabled: _enabled,
        apiKey: _apiKey.text.trim(),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String _typeLabel(AiProviderType type) => switch (type) {
    AiProviderType.openAi => 'OpenAI',
    AiProviderType.gemini => 'Google Gemini',
    AiProviderType.openAiCompatible => 'OpenAI-compatible',
    AiProviderType.groq => 'Groq',
    AiProviderType.anthropic => 'Anthropic',
  };
}
