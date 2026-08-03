import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/nutrition_analysis_service.dart';
import '../theme/app_theme.dart';

class AiSuggestionsCard extends StatefulWidget {
  final String date;

  const AiSuggestionsCard({super.key, required this.date});

  @override
  State<AiSuggestionsCard> createState() => _AiSuggestionsCardState();
}

class _AiSuggestionsCardState extends State<AiSuggestionsCard> {
  List<String>? _suggestions;
  String? _motivationalQuote;
  Map<String, dynamic>? _insights;
  bool _isLoading = false;
  bool _hasApiKey = false;
  bool _hasEnoughData = false;
  bool _loaded = false;

  /// Collapsed by default once insights already exist (i.e. generated on a
  /// previous visit). A fresh generation expands the card.
  bool _collapsed = true;

  @override
  void initState() {
    super.initState();
    _loadAiData();
  }

  Future<void> _loadAiData() async {
    _hasApiKey = await SettingsService.hasGeminiApiKey();
    _hasEnoughData = await NutritionAnalysisService.hasEnoughDataForAnalysis();

    if (_hasApiKey && _hasEnoughData) {
      final insights = await SettingsService.getDailyAiInsights(widget.date);
      final suggestions = await SettingsService.getDailyAiSuggestions(
        widget.date,
      );
      final quote = await SettingsService.getAiQuote();

      if (mounted) {
        setState(() {
          _insights = insights;
          _suggestions = (insights?['tips'] as List?)?.cast<String>() ??
              suggestions;
          _motivationalQuote =
              (insights?['quote'] as String?) ?? quote;
          // Existing insights start collapsed; the header stays as a peek.
          _collapsed = true;
        });
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _generateSuggestions() async {
    if (!_hasApiKey || !_hasEnoughData) return;

    setState(() => _isLoading = true);

    try {
      final result = await NutritionAnalysisService.analyzeDailyNutrition(
        widget.date,
      );

      if (result != null && mounted) {
        setState(() {
          _insights = result;
          _suggestions = (result['tips'] as List?)?.cast<String>() ??
              (result['suggestions'] as List?)?.cast<String>();
          _motivationalQuote =
              (result['quote'] ?? result['motivationalQuote']) as String?;
          _isLoading = false;
          _collapsed = false; // reveal the freshly generated insights
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate insights: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _dismiss() async {
    await SettingsService.clearDailyAiSuggestions(widget.date);
    if (mounted) {
      setState(() {
        _suggestions = null;
        _motivationalQuote = null;
        _insights = null;
        _collapsed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Avoid a flash before we know the state.
    if (!_loaded || !_hasApiKey) return const SizedBox.shrink();

    if (!_hasEnoughData) return _infoTile(context);

    final hasSuggestions = _suggestions != null && _suggestions!.isNotEmpty;
    if (hasSuggestions) return _insightsCard(context);

    return _generatePrompt(context);
  }

  // ---------------------------------------------------------------------------
  // Not-enough-data state.
  Widget _infoTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary, size: 22),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              'Log meals for a few days to unlock AI nutrition insights.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Collapsible insights card.
  Widget _insightsCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (always visible; tapping toggles collapse).
          Semantics(
            button: true,
            label: 'AI nutrition insights',
            hint: _collapsed ? 'Expand' : 'Collapse',
            child: InkWell(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space12,
                  AppTheme.space8,
                  AppTheme.space4,
                  AppTheme.space8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: scheme.onPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI nutrition insights',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          // Give the collapsed state a value peek.
                          if (_collapsed)
                            Text(
                              (_insights?['headline'] as String?) ??
                                  '${_suggestions!.length} tip'
                                      '${_suggestions!.length == 1 ? '' : 's'} · tap to view',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onSelected: (v) {
                        if (v == 'regenerate') {
                          _generateSuggestions();
                        } else if (v == 'remove') {
                          _dismiss();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'regenerate',
                          child: Text('Regenerate'),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove insights'),
                        ),
                      ],
                    ),
                    // Caret that flips between ^ (open) and v (collapsed).
                    AnimatedRotation(
                      turns: _collapsed ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body.
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _insightsBody(context),
            crossFadeState: _collapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _insightsBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space12,
        0,
        AppTheme.space12,
        AppTheme.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_insights?['focus'] is String &&
              (_insights!['focus'] as String).trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.center_focus_strong_rounded,
                      size: 18, color: scheme.tertiary),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Focus',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          _insights!['focus'] as String,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          if (_motivationalQuote != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                _motivationalQuote!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          ..._suggestions!.asMap().entries.map((entry) {
            final index = entry.key;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _suggestions!.length - 1 ? AppTheme.space8 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_insights?['action'] is Map &&
              (_insights!['action']['title'] as String?)?.trim().isNotEmpty ==
                  true) ...[
            const SizedBox(height: AppTheme.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_task_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      _insights!['action']['title'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _generateSuggestions,
              icon: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scheme.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isLoading ? 'Analyzing…' : 'Regenerate'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // First-run generate prompt (compact).
  Widget _generatePrompt(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary, size: 22),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI nutrition insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Personalized tips from today\'s intake.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          FilledButton(
            onPressed: _isLoading ? null : _generateSuggestions,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
