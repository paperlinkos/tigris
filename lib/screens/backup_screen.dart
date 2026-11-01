import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../repositories/backup_store.dart';
import '../services/backup_format.dart';
import '../services/backup_service.dart';
import '../services/drive_account.dart';
import '../widgets/calm_scaffold.dart';

class BackupScreen extends StatefulWidget {
  final BackupService service;
  final DriveAccount account;
  const BackupScreen({super.key, required this.service, required this.account});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = true;
  bool _connected = false;
  String? _error;
  List<BackupFile> _backups = const [];

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final connected = await widget.account.connectSilently();
    if (!mounted) return;
    setState(() { _connected = connected; _busy = false; });
    if (connected) await _load();
  }

  String _message(Object error) {
    if (error is BackupFormatException) return error.message;
    if (error is PlatformException) return "Google sign-in isn't set up for this app yet. Your notes are safe on this device.";
    if (error is BackupNotConnectedException) return 'Connect Google Drive to continue.';
    if (error is SocketException || error is TimeoutException) return "Couldn't reach Google Drive. Your notes are safe on this device.";
    if (error is BackupStoreException && error.statusCode == 403) return 'Google Drive refused access. Check that the Drive API is turned on for this app.';
    return "Couldn't reach Google Drive. Your notes are safe on this device.";
  }

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; });
    try {
      final backups = await widget.service.listBackups();
      if (mounted) setState(() => _backups = backups);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    setState(() { _busy = true; _error = null; });
    try {
      final connected = await widget.account.connect();
      if (!mounted) return;
      setState(() => _connected = connected);
      if (connected) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await widget.service.backupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result == null ? 'There are no notes to back up yet.' : 'Backup saved.')));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(BackupFile file) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text('Notes in this backup will replace the same notes on this device. Other notes stay as they are. A backup of your current notes is saved first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final count = await widget.service.restore(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $count notes.')));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dateLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = date.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, ${local.hour}:$minute';
  }

  @override
  Widget build(BuildContext context) => CalmScaffold(
    title: 'BACKUP',
    body: ListView(padding: const EdgeInsets.only(top: 20), children: [
      Text('Google Drive Backup', style: AppTypography.title(fontSize: 26, color: context.appTextPrimary)),
      const SizedBox(height: 12),
      if (_busy) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
      else if (!_connected) ...[
        Text('Keep a copy of your notes in your own Google Drive. Tigris can only see the files it creates there.', style: AppTypography.body(fontSize: 14, color: context.appTextSecondary)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _connect, child: const Text('Connect Google Drive')),
      ] else ...[
        Text(widget.account.email ?? '', style: AppTypography.uiLabel(fontSize: 13, color: context.appTextSecondary)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _backup, child: const Text('Back up now')),
        TextButton(onPressed: () async { await widget.account.disconnect(); if (mounted) setState(() { _connected = false; _backups = const []; }); }, child: const Text('Disconnect')),
        Text('Disconnecting does not delete anything from Drive.', style: AppTypography.uiLabel(fontSize: 12, color: context.appTextSecondary)),
        const SizedBox(height: 24),
        Text('Backups', style: AppTypography.uiHeadline(fontSize: 16, color: context.appTextPrimary)),
        const SizedBox(height: 8),
        if (_backups.isEmpty) Text('No backups yet.', style: AppTypography.body(fontSize: 14, color: context.appTextSecondary))
        else ..._backups.map((file) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_dateLabel(file.createdAt), style: AppTypography.uiHeadline(fontSize: 14, color: context.appTextPrimary)),
          subtitle: file.name.contains('-before-restore')
              ? Text('Saved automatically before a restore', style: AppTypography.uiLabel(fontSize: 12, color: context.appTextSecondary))
              : null,
          onTap: () => _restore(file),
        )),
      ],
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: AppTypography.body(fontSize: 14, color: context.appTextSecondary))),
    ]),
  );
}
