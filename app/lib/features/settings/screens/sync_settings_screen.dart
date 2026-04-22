import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/sync_bootstrap.dart';
import '../../../core/sync/sync_config.dart';
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  SyncBootstrap get _bootstrap => context.read<SyncBootstrap>();

  @override
  void initState() {
    super.initState();
    final config = context.read<SyncConfigCubit>().state.config;
    _urlController.text = config.serverUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final cubit = context.read<SyncConfigCubit>();
      await cubit.setServerUrl(url);
      await cubit.setEnabled(true);
      // Rebuild the shared auth + engine against the new URL.
      await _bootstrap.onServerUrlChanged(url);
      if (!mounted) return;
      if (_bootstrap.auth.isAuthenticated) {
        cubit.setAuthenticated(true);
      }
      setState(() {
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await _bootstrap.auth.register(email, password);
      } else {
        await _bootstrap.auth.login(email, password);
      }
      if (!mounted) return;
      // Build engine + attach auto-sync; kick off an immediate sync.
      _bootstrap.onAuthenticated();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = _isRegisterMode
            ? 'Registration failed: $e'
            : 'Login failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    final cubit = context.read<SyncConfigCubit>();
    cubit.setStatus(SyncStatus.syncing);

    try {
      // AutoSyncService owns the shared engine; it handles single-flight,
      // backoff, and advances lastSyncAt only on full success.
      final result = await _bootstrap.autoSyncService.syncNow();
      if (!mounted) return;
      if (result == null || result.skippedAlreadyRunning) {
        // Another sync was in-flight; it will update status on completion.
        return;
      }
      if (result.authFailed) {
        cubit.setStatus(SyncStatus.error,
            errorMessage: 'Authentication expired. Please log in again.');
        cubit.setAuthenticated(false);
        return;
      }
      if (result.failedCollections.isEmpty && result.syncedAt != null) {
        cubit.setStatus(SyncStatus.connected);
      } else {
        cubit.setStatus(
          SyncStatus.error,
          errorMessage:
              'Sync partially failed: ${result.failedCollections.join(', ')}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      cubit.setStatus(SyncStatus.error, errorMessage: 'Sync failed: $e');
    }
  }

  Future<void> _logout() async {
    await _bootstrap.onLogout();
    if (!mounted) return;
    final cubit = context.read<SyncConfigCubit>();
    cubit.setAuthenticated(false);
    cubit.setStatus(SyncStatus.disconnected);
    _emailController.clear();
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Settings')),
      body: BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(state),
              const SizedBox(height: 16),
              _buildServerSection(state),
              if (state.config.serverUrl.isNotEmpty &&
                  !state.isAuthenticated) ...[
                const SizedBox(height: 16),
                _buildAuthSection(),
              ],
              if (state.isAuthenticated) ...[
                const SizedBox(height: 16),
                _buildSyncSection(state),
                const SizedBox(height: 16),
                _buildAccountSection(),
              ],
              if (state.recentErrors.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildErrorLog(state.recentErrors),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(SyncConfigState state) {
    final (icon, color, label) = switch (state.status) {
      SyncStatus.disconnected => (
          Icons.cloud_off,
          Colors.grey,
          'Disconnected'
        ),
      SyncStatus.connecting => (
          Icons.cloud_queue,
          Colors.orange,
          'Connecting...'
        ),
      SyncStatus.connected => (
          Icons.cloud_done,
          Colors.green,
          'Connected'
        ),
      SyncStatus.syncing => (
          Icons.sync,
          Colors.blue,
          'Syncing...'
        ),
      SyncStatus.error => (
          Icons.cloud_off,
          Colors.red,
          'Error'
        ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: state.config.lastSyncAt != null
            ? Text(
                'Last synced: ${DateFormat.yMMMd().add_jm().format(state.config.lastSyncAt!)}')
            : const Text('Never synced'),
      ),
    );
  }

  Widget _buildServerSection(SyncConfigState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://your-server.com',
                prefixIcon: Icon(Icons.dns_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              enabled: !state.isAuthenticated,
            ),
            const SizedBox(height: 12),
            if (!state.isAuthenticated)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveServerUrl,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Connect'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isRegisterMode ? 'Create Account' : 'Login',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    setState(
                        () => _isRegisterMode = !_isRegisterMode);
                  },
                  child: Text(_isRegisterMode
                      ? 'Have an account? Login'
                      : 'New? Register'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outlined),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _authenticate,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isRegisterMode
                        ? Icons.person_add
                        : Icons.login),
                label: Text(_isRegisterMode ? 'Register' : 'Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection(SyncConfigState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic sync'),
              subtitle: const Text(
                'Sync in the background on startup, foreground, '
                'and after changes.',
              ),
              value: state.config.autoSyncEnabled,
              onChanged: (v) {
                final cubit = context.read<SyncConfigCubit>();
                cubit.setAutoSyncEnabled(v);
                _bootstrap.autoSyncService.setAutoSyncEnabled(v);
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.status == SyncStatus.syncing
                    ? null
                    : _syncNow,
                icon: state.status == SyncStatus.syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(state.status == SyncStatus.syncing
                    ? 'Syncing...'
                    : 'Sync Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorLog(List<SyncError> errors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Sync Errors',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    context.read<SyncConfigCubit>().clearErrors();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...errors.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.collection,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        Text(e.message,
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          DateFormat.Hm().format(e.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _errorMessage = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
