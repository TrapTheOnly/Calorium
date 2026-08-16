import 'package:flutter/material.dart';
import '../screens/recipe_import_screen.dart';
import '../services/share_intent_service.dart';
import '../theme/app_theme.dart';

class _ImportRequest {
  final String url;
  final String? caption;
  const _ImportRequest({required this.url, this.caption});
}

/// In-app entry for importing a recipe from an Instagram or YouTube link.
class ImportRecipeUrlSheet extends StatefulWidget {
  const ImportRecipeUrlSheet({super.key});

  /// Shows the sheet, then pushes [RecipeImportScreen] when the user submits.
  static Future<void> show(BuildContext context) async {
    final request = await showModalBottomSheet<_ImportRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const ImportRecipeUrlSheet(),
      ),
    );
    if (request == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeImportScreen(
          sharedUrl: request.url,
          pastedCaption: request.caption,
        ),
      ),
    );
  }

  @override
  State<ImportRecipeUrlSheet> createState() => _ImportRecipeUrlSheetState();
}

class _ImportRecipeUrlSheetState extends State<ImportRecipeUrlSheet> {
  final _urlController = TextEditingController();
  final _captionController = TextEditingController();
  String? _urlError;

  static final _urlPattern = RegExp(r'https?:\/\/[^\s]+', caseSensitive: false);

  @override
  void dispose() {
    _urlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  String _extractUrl(String raw) {
    final match = _urlPattern.firstMatch(raw.trim());
    return (match?.group(0) ?? raw).trim();
  }

  void _submit() {
    final url = _extractUrl(_urlController.text);
    if (url.isEmpty || !ShareIntentService.isSupportedRecipeUrl(url)) {
      setState(() {
        _urlError =
            'Only Instagram and YouTube links can be imported as recipes.';
      });
      return;
    }
    final caption = _captionController.text.trim();
    Navigator.of(context).pop(
      _ImportRequest(
        url: url,
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          AppTheme.space8,
          AppTheme.pagePadding,
          AppTheme.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Import from link', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Paste an Instagram or YouTube recipe link.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (_) {
                if (_urlError != null) setState(() => _urlError = null);
              },
              decoration: InputDecoration(
                labelText: 'Recipe link',
                hintText: 'https://…',
                prefixIcon: const Icon(Icons.link_rounded),
                errorText: _urlError,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: _captionController,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Caption (if the link has no text)',
                hintText: 'Optional — paste the recipe caption',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Import recipe'),
            ),
          ],
        ),
      ),
    );
  }
}
