import 'package:flutter/material.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../services/glossary_service.dart';
import '../widgets/calm_scaffold.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  Map<String, String> _glossary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGlossary();
  }

  Future<void> _loadGlossary() async {
    final terms = await GlossaryService.getGlossary();
    if (mounted) {
      setState(() {
        _glossary = terms;
        _isLoading = false;
      });
    }
  }

  void _showAddEditDialog([String? initialTerm, String? initialDef]) {
    final termController = TextEditingController(text: initialTerm ?? '');
    final defController = TextEditingController(text: initialDef ?? '');
    final isEditing = initialTerm != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: context.appBorderSubtle),
        ),
        title: Text(
          isEditing ? 'Edit Acronym / Term' : 'Add Acronym / Term',
          style: AppTypography.uiHeadline(fontSize: 17.0, color: context.appTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: termController,
              enabled: !isEditing,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: context.appTextPrimary),
              decoration: InputDecoration(
                labelText: 'Acronym or Term',
                hintText: 'e.g. HEZP, ROR, PC',
                labelStyle: TextStyle(color: context.appTextSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
            const SizedBox(height: 14.0),
            TextField(
              controller: defController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: context.appTextPrimary),
              decoration: InputDecoration(
                labelText: 'Meaning / Full Title',
                hintText: 'e.g. Highly Esteemed Zonal Pastor',
                labelStyle: TextStyle(color: context.appTextSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: context.appTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTextPrimary,
              foregroundColor: context.appBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onPressed: () async {
              final term = termController.text.trim();
              final def = defController.text.trim();
              if (term.isNotEmpty && def.isNotEmpty) {
                await GlossaryService.addOrUpdateTerm(term, def);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadGlossary();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTerm(String term) async {
    await GlossaryService.removeTerm(term);
    _loadGlossary();
  }

  @override
  Widget build(BuildContext context) {
    return CalmScaffold(
      title: 'AI GLOSSARY & MEMORY',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 16.0, bottom: 40.0),
              children: [
                Text(
                  'Ministry Acronyms & Context',
                  style: AppTypography.title(fontSize: 22.0, color: context.appTextPrimary),
                ),
                const SizedBox(height: 6.0),
                Text(
                  'These acronyms and titles are fed directly to Gemini so it understands church speakers, meeting structures, and ministry terminology accurately.',
                  style: AppTypography.body(fontSize: 13.5, color: context.appTextSecondary),
                ),
                const SizedBox(height: 20.0),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add, size: 18.0),
                  label: const Text('Add New Acronym / Term'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appTextPrimary,
                    foregroundColor: context.appBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
                const SizedBox(height: 24.0),
                Container(
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: context.appBorderSubtle),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _glossary.length,
                    separatorBuilder: (ctx, idx) => Divider(height: 1.0, color: context.appBorderSubtle),
                    itemBuilder: (context, index) {
                      final key = _glossary.keys.elementAt(index);
                      final value = _glossary[key]!;
                      final isDefault = GlossaryService.defaultMinistryGlossary.containsKey(key);

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        title: Row(
                          children: [
                            Text(
                              key,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                                color: context.appTextPrimary,
                              ),
                            ),
                            if (isDefault) ...[
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Text(
                                  'Built-in',
                                  style: TextStyle(fontSize: 10.0, color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          value,
                          style: TextStyle(fontSize: 13.0, color: context.appTextSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18.0),
                              color: context.appTextSecondary,
                              onPressed: () => _showAddEditDialog(key, value),
                            ),
                            if (!isDefault)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18.0),
                                color: Colors.redAccent,
                                onPressed: () => _deleteTerm(key),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
