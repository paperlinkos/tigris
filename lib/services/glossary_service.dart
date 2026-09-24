import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GlossaryService {
  static const String _storageKey = 'tigris_ai_glossary';

  static const Map<String, String> defaultMinistryGlossary = {
    'HEZP': 'Highly Esteemed Zonal Pastor',
    'HE': 'Highly Esteemed',
    'ZP': 'Zonal Pastor',
    'PC': 'Pastor Chris (Oyakhilome)',
    'BLW': 'Believers LoveWorld / Christ Embassy',
    'ROR': 'Rhapsody of Realities',
    'PCDL': 'Pastor Chris Digital Library',
    'IPPC': 'International Pastors and Partners Conference',
    'WEC': 'World Evangelism Conference',
    'First Service': 'The morning / first church service session',
    'Second Service': 'The second church service session',
    'Midweek Service': 'Wednesday church service session',
  };

  static Future<Map<String, String>> getGlossary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final custom = <String, String>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          custom[entry.key] = entry.value.toString();
        }
      } catch (_) {}
    }

    // Merge default ministry glossary with any custom user terms (custom overrides defaults)
    return {
      ...defaultMinistryGlossary,
      ...custom,
    };
  }

  static Future<void> addOrUpdateTerm(String term, String definition) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final custom = <String, String>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          custom[entry.key] = entry.value.toString();
        }
      } catch (_) {}
    }

    custom[term.trim()] = definition.trim();
    await prefs.setString(_storageKey, jsonEncode(custom));
  }

  static Future<void> removeTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.remove(term.trim());
      await prefs.setString(_storageKey, jsonEncode(decoded));
    } catch (_) {}
  }

  static Future<String> formatGlossaryPrompt() async {
    final glossary = await getGlossary();
    if (glossary.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('KNOWN MINISTRY & DOMAIN GLOSSARY / ACRONYMS:');
    for (final entry in glossary.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
    return buffer.toString();
  }
}
