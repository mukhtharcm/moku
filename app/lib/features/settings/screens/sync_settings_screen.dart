import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/auth_service.dart';
import '../../../core/sync/sync_config.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/database/database.dart';

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

  late final AuthService _authService;
  SyncEngine? _syncEngine;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    final config = context.read<SyncConfigCubit>().state.config;
    _urlController.text = config.serverUrl;
    if (config.serverUrl.isNotEmpty) {
      _initAuth(config.serverUrl);
    }
  }

  Future<void> _initAuth(String serverUrl) async {
    await _authService.init(serverUrl);
    if (!mounted) return;
    if (_authService.isAuthenticated) {
      context.read<SyncConfigCubit>().setAuthenticated(true);
      _initSyncEngine();
    }
  }

  void _initSyncEngine() {
    if (_authService.pb != null) {
      final db = context.read<AppDatabase>();
      _syncEngine = SyncEngine(pb: _authService.pb!, db: db);
    }
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
      await context.read<SyncConfigCubit>().setServerUrl(url);
      await _authService.init(url);
      if (!mounted) return;
      await context.read<SyncConfigCubit>().setEnabled(true);
      if (!mounted) return;
      if (_authService.isAuthenticated) {
        context.read<SyncConfigCubit>().setAuthenticated(true);
        _initSyncEngine();
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
        await _authService.register(email, password);
      } else {
        await _authService.login(email, password);
      }
      if (!mounted) return;
      context.read<SyncConfigCubit>().setAuthenticated(true);
      _initSyncEngine();
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
    if (_syncEngine == null) return;

    final cubit = context.read<SyncConfigCubit>();
    cubit.setStatus(SyncStatus.syncing);

    try {
      final syncTime = await _syncEngine!.syncAll(
        lastSyncAt: cubit.state.config.lastSyncAt,
      );
      await cubit.updateLastSyncAt(syncTime);
      cubit.setStatus(SyncStatus.connected);
    } catch (e) {
      cubit.setStatus(SyncStatus.error, errorMessage: 'Sync failed: $e');
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    context.read<SyncConfigCubit>().setAuthenticated(false);
    context.read<SyncConfigCubit>().setStatus(SyncStatus.disconnected);
    _syncEngine = null;
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
            const SizedBox(height: 12),
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
