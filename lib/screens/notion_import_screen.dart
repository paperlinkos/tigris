import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../models/note.dart';
import '../persistence/preferences_storage.dart';
import '../services/notion_import_service.dart';
import '../widgets/calm_scaffold.dart';

enum NotionImportStep { tokenInput, selectPages, importing, summary }

class NotionImportScreen extends StatefulWidget {
  final NotionImportService? notionService;

  const NotionImportScreen({
    super.key,
    this.notionService,
  });

  @override
  State<NotionImportScreen> createState() => _NotionImportScreenState();
}

class _NotionImportScreenState extends State<NotionImportScreen> {
  late final NotionImportService _notionService;
  final TextEditingController _tokenController = TextEditingController();
  final PreferencesStorage _storage = PreferencesStorage();

  NotionImportStep _step = NotionImportStep.tokenInput;
  bool _isLoading = false;
  String? _errorMessage;

  List<NotionPage> _pages = [];
  final Set<String> _selectedPageIds = {};
  double _importProgress = 0.0;
  String _importProgressStatus = '';
  List<Note> _importedNotes = [];

  @override
  void initState() {
    super.initState();
    _notionService = widget.notionService ?? NotionImportService();
    _loadSavedToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedToken() async {
    final saved = await _storage.get('notion_config', 'integration_token');
    if (saved != null && saved['token'] != null) {
      final t = saved['token'] as String;
      _tokenController.text = t;
    }
  }

  Future<void> _fetchPages() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Notion Integration Token.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _storage.set('notion_config', 'integration_token', {'token': token});
      final pages = await _notionService.fetchAccessiblePages(token);

      if (mounted) {
        setState(() {
          _pages = pages;
          _selectedPageIds.addAll(pages.map((p) => p.id));
          _step = NotionImportStep.selectPages;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startImport() async {
    final token = _tokenController.text.trim();
    final selected = _pages.where((p) => _selectedPageIds.contains(p.id)).toList();

    if (selected.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one page to import.');
      return;
    }

    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) {
      setState(() => _errorMessage = 'Note repository scope not available.');
      return;
    }

    setState(() {
      _step = NotionImportStep.importing;
      _importProgress = 0.0;
      _importProgressStatus = 'Preparing import...';
      _errorMessage = null;
    });

    try {
      final notes = await _notionService.importSelectedPages(
        token: token,
        selectedPages: selected,
        noteRepository: repoScope.noteRepository,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _importProgress = progress;
              _importProgressStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _importedNotes = notes;
          _step = NotionImportStep.summary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = NotionImportStep.selectPages;
          _errorMessage = 'Import error: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CalmScaffold(
      title: 'NOTION IMPORT',
      body: _buildStepBody(),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case NotionImportStep.tokenInput:
        return _buildTokenInputStep();
      case NotionImportStep.selectPages:
        return _buildSelectPagesStep();
      case NotionImportStep.importing:
        return _buildImportingStep();
      case NotionImportStep.summary:
        return _buildSummaryStep();
    }
  }

  Widget _buildTokenInputStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to Notion',
            style: AppTypography.title(
              fontSize: 24.0,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Import pages and subpages directly from your Notion workspace as native Tigris notes.',
            style: AppTypography.subtitle(
              fontSize: 14.0,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 28.0),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: AppTypography.body(fontSize: 13.5, color: Colors.red),
              ),
            ),
          ],

          Text(
            'NOTION INTEGRATION TOKEN',
            style: AppTypography.uiLabel(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ).copyWith(letterSpacing: 1.1),
          ),
          const SizedBox(height: 8.0),
          TextFormField(
            controller: _tokenController,
            obscureText: true,
            style: AppTypography.body(fontSize: 15.0, color: context.appTextPrimary),
            decoration: InputDecoration(
              hintText: 'secret_...',
              hintStyle: TextStyle(color: context.appTextTertiary),
              filled: true,
              fillColor: context.appSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide(color: context.appBorderSubtle),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Text(
            'Create an Internal Integration Token at notion.so/my-integrations and grant page access.',
            style: AppTypography.uiLabel(
              fontSize: 12.0,
              color: context.appTextTertiary,
            ),
          ),
          const SizedBox(height: 32.0),

          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _fetchPages,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appTextPrimary,
                foregroundColor: context.appBg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: context.appBg,
                      ),
                    )
                  : Text(
                      'Connect & Fetch Pages',
                      style: AppTypography.uiHeadline(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.appBg,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectPagesStep() {
    final allSelected = _selectedPageIds.length == _pages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Pages to Import',
                  style: AppTypography.title(fontSize: 22.0, color: context.appTextPrimary),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '${_pages.length} accessible Notion pages found',
                  style: AppTypography.subtitle(fontSize: 13.0, color: context.appTextSecondary),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedPageIds.clear();
                  } else {
                    _selectedPageIds.addAll(_pages.map((p) => p.id));
                  }
                });
              },
              child: Text(
                allSelected ? 'Deselect All' : 'Select All',
                style: AppTypography.uiLabel(fontSize: 13.0, color: context.appTextPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        if (_errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13.0),
            ),
          ),
        ],

        Expanded(
          child: _pages.isEmpty
              ? Center(
                  child: Text(
                    'No accessible pages found in Notion workspace.',
                    style: AppTypography.body(fontSize: 14.0, color: context.appTextSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _pages.length,
                  separatorBuilder: (context, index) => Divider(color: context.appBorderSubtle, height: 1.0),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    final isChecked = _selectedPageIds.contains(page.id);

                    return CheckboxListTile(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedPageIds.add(page.id);
                          } else {
                            _selectedPageIds.remove(page.id);
                          }
                        });
                      },
                      activeColor: context.appTextPrimary,
                      checkColor: context.appBg,
                      title: Text(
                        '${page.icon ?? '📄'} ${page.title}',
                        style: AppTypography.uiHeadline(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Edited ${page.lastEditedAt.day}/${page.lastEditedAt.month}/${page.lastEditedAt.year}',
                        style: AppTypography.uiLabel(fontSize: 12.0, color: context.appTextTertiary),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16.0),

        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: _selectedPageIds.isEmpty ? null : _startImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTextPrimary,
              foregroundColor: context.appBg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: Text(
              'Import (${_selectedPageIds.length} pages)',
              style: AppTypography.uiHeadline(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: context.appBg,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportingStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48.0,
            height: 48.0,
            child: CircularProgressIndicator(
              value: _importProgress > 0 ? _importProgress : null,
              strokeWidth: 3.0,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 24.0),
          Text(
            'Importing Notion Content...',
            style: AppTypography.title(fontSize: 20.0, color: context.appTextPrimary),
          ),
          const SizedBox(height: 8.0),
          Text(
            _importProgressStatus,
            style: AppTypography.body(fontSize: 14.0, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64.0,
              color: context.appTextPrimary,
            ),
            const SizedBox(height: 20.0),
            Text(
              'Import Complete!',
              style: AppTypography.display(fontSize: 26.0, color: context.appTextPrimary),
            ),
            const SizedBox(height: 10.0),
            Text(
              'Successfully converted ${_importedNotes.length} pages and subpages into native Tigris notes.',
              textAlign: TextAlign.center,
              style: AppTypography.body(fontSize: 15.0, color: context.appTextSecondary),
            ),
            const SizedBox(height: 36.0),
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appTextPrimary,
                  foregroundColor: context.appBg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                ),
                child: Text(
                  'Done & View Notes',
                  style: AppTypography.uiHeadline(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: context.appBg,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
