import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_core/server_core.dart';

import '../../../navigation/destinations.dart';
import '../../../widgets/adaptive/adaptive_dialog.dart';
import '../../detail/modern/widgets/details_tab_bar.dart';
import '../admin_draft.dart';
import '../admin_nav.dart';
import '../widgets/admin_form_styles.dart';
import '../widgets/premiere_note.dart';
import '../providers/admin_user_providers.dart';
import 'admin_user_delete_dialog.dart';
import 'download_limits_section.dart';
import '../../../../data/services/tortugarr/download_features.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../util/error_message.dart';
import '../../../../util/platform_detection.dart';

typedef _RatingOption = ({String name, int score, int? subScore});

/// One user's profile, permissions, access, parental control and password.
/// The UserDto and its Policy are one draft with two targets, saved by the
/// shell's bar. Password set and reset act at once.
class AdminUserEditScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminUserEditScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserEditScreen> createState() =>
      _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends ConsumerState<AdminUserEditScreen>
    with AdminDraftHost {
  int _selectedTab = 0;
  final _tabFocusNodes = <int, FocusNode>{};
  late final MediaServerClient _client;

  /// The UserDto as fetched, minus Policy, which [_policy] edits.
  late Map<String, dynamic> _profile;
  late Map<String, dynamic> _policy;
  List<VirtualFolderInfo> _libraries = const [];
  List<Map<String, dynamic>> _channels = const [];
  List<Map<String, dynamic>> _deletableChannels = const [];
  List<_RatingOption> _ratings = const [];
  List<Map<String, dynamic>> _authProviders = const [];
  List<Map<String, dynamic>> _resetProviders = const [];
  List<DeviceInfoDto> _devices = const [];
  bool _serverRemoteAccess = true;

  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _connectController = TextEditingController();
  final _tagControllers = <String, TextEditingController>{};

  bool _loading = true;
  bool _passwordBusy = false;
  bool _connectBusy = false;
  String? _error;

  /// The Emby Connect account the user is linked to, empty when none.
  String _connectLinked = '';

  /// Set on every build, for the draft's posts, which may finish after the
  /// page has gone.
  late AppLocalizations _l10n;

  AdminUsersApi get _users => _client.adminUsersApi;

  @override
  void initState() {
    super.initState();
    _client = GetIt.instance<MediaServerClient>();
    _load();
  }

  FocusNode _tabNode(int index) {
    return _tabFocusNodes.putIfAbsent(
        index, () => FocusNode(debugLabel: 'admin_user_tab_$index'));
  }

  @override
  void dispose() {
    for (final node in _tabFocusNodes.values) {
      node.dispose();
    }
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _connectController.dispose();
    for (final c in _tagControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchUser() async =>
      Map<String, dynamic>.of((await _users.getUserById(widget.userId)).raw);

  // A missing Policy throws, so a partial policy is never posted.
  Future<Map<String, dynamic>> _fetchPolicy() async =>
      Map<String, dynamic>.from((await _fetchUser())['Policy'] as Map);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Reference lists are optional, so a failed one is empty instead of
      // failing the whole screen. They load alongside the user.
      Future<List<Map<String, dynamic>>> list(
        Future<List<Map<String, dynamic>>> call,
      ) => call.catchError((_) => <Map<String, dynamic>>[]);
      final ratingsLoad = list(_client.adminSystemApi.getParentalRatings());
      final authLoad = list(_client.adminSystemApi.getAuthProviders());
      final resetLoad =
          list(_client.adminSystemApi.getPasswordResetProviders());
      final channelsLoad = list(_users.getChannels());
      final deletableLoad =
          list(_users.getChannels(supportsMediaDeletion: true));
      final devicesLoad = _client.adminDevicesApi
          .getDevices()
          .catchError((_) => <DeviceInfoDto>[]);
      // Emby keeps the remote access switch in the base configuration.
      final networkLoad = (_emby
              ? _client.adminSystemApi.getServerConfiguration()
              : _client.adminSystemApi.getNamedConfiguration('network'))
          .catchError((_) => <String, dynamic>{});
      final user = await _fetchUser();
      final libraries = await _client.adminLibraryApi.getMediaFolders(
        isHidden: false,
      );
      final ratings = await ratingsLoad;
      final authProviders = await authLoad;
      final resetProviders = await resetLoad;
      final channels = await channelsLoad;
      final deletable = await deletableLoad;
      final devices = await devicesLoad;
      final network = await networkLoad;
      if (!mounted) return;
      final policy = Map<String, dynamic>.from(user['Policy'] as Map);
      final profile = user..remove('Policy');
      setState(() {
        _profile = profile;
        _policy = policy;
        _libraries = libraries;
        _ratings = _groupRatings(ratings);
        _authProviders = authProviders;
        _resetProviders = resetProviders;
        _channels = channels;
        _deletableChannels = deletable;
        _devices = devices;
        _serverRemoteAccess = network['EnableRemoteAccess'] != false;
        _connectLinked = _connectController.text =
            '${user['ConnectUserName'] ?? ''}';
        _loading = false;
      });
      hostDraft(AdminDraft({
        // The whole UserDto goes back, so the user's Configuration survives a
        // rename.
        'profile': AdminDraftTarget(
          working: profile,
          reload: _fetchUser,
          post: (dto) async {
            final name = '${dto['Name'] ?? ''}'.trim();
            if (name.isEmpty) throw Exception(_l10n.adminUsernameRequired);
            await _users.updateUser(widget.userId, {...dto, 'Name': name});
            if (mounted) ref.invalidate(adminUsersListProvider);
          },
        ),
        'policy': AdminDraftTarget(
          working: policy,
          reload: _fetchPolicy,
          post: (value) async {
            if (_badSchedule(value) != null) {
              throw Exception(_l10n.adminScheduleStartBeforeEnd);
            }
            await _users.updateUserPolicy(widget.userId, value);
            if (mounted) ref.invalidate(adminUsersListProvider);
          },
        ),
      }));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e, AppLocalizations.of(context));
        _loading = false;
      });
    }
  }

  void _editPolicy(void Function(Map<String, dynamic> policy) change) {
    setState(() => change(_policy));
    edited();
  }

  /// Null removes the key, so clearing a nullable value the server left out
  /// doesn't count as an edit.
  void _setPolicy(String key, Object? value) => _editPolicy((p) {
        if (value == null) {
          p.remove(key);
        } else {
          p[key] = value;
        }
      });

  List<String> _listOf(String key) =>
      List<String>.from(_policy[key] as List? ?? const []);

  void _toggleListMembership(String key, String value, bool enabled) {
    final list = _listOf(key)..remove(value);
    if (enabled) list.add(value);
    _setPolicy(key, list);
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _savePassword() async {
    final l10n = AppLocalizations.of(context);
    final pw = _passwordController.text;
    if (pw != _confirmPasswordController.text) {
      _snack(l10n.adminPasswordsMismatch);
      return;
    }
    // An administrator can't be left without a password.
    if (pw.isEmpty && _isAdmin) {
      _snack(l10n.adminNewPasswordEmpty);
      return;
    }
    await _passwordAction(
      () => _users.updateUserPassword(
        widget.userId,
        currentPassword: _isSelf ? _currentPasswordController.text : null,
        newPassword: pw,
      ),
      l10n.adminPasswordUpdated,
    );
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(l10n.adminResetPassword),
        content: Text(l10n.adminResetPasswordWarning),
        actions: [
          adaptiveDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _passwordAction(
      () => _users.updateUserPassword(widget.userId, resetPassword: true),
      l10n.adminPasswordReset,
    );
  }

  Future<void> _passwordAction(
    Future<void> Function() call,
    String done,
  ) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _passwordBusy = true);
    try {
      await call();
      if (!mounted) return;
      _currentPasswordController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _snack(done);
    } catch (e) {
      if (mounted) _snack(l10n.adminFailed(describeError(e, l10n)));
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  /// Links or unlinks right away rather than with the draft's save.
  Future<void> _setConnect({required bool link}) async {
    final l10n = AppLocalizations.of(context);
    final emby = _client.embyAdminApi!;
    final name = _connectController.text.trim();
    if (link && name.isEmpty) return;
    setState(() => _connectBusy = true);
    try {
      var pending = false;
      if (link) {
        final result = await emby.linkConnectUser(widget.userId, name);
        pending = result['IsPending'] == true;
      } else {
        await emby.unlinkConnectUser(widget.userId);
      }
      final linked = '${(await _fetchUser())['ConnectUserName'] ?? ''}';
      if (!mounted) return;
      setState(() => _connectLinked = _connectController.text = linked);
      _snack(link
          ? (pending ? l10n.adminEmbyConnectPending : l10n.adminEmbyConnectLinked)
          : l10n.adminEmbyConnectUnlinked);
    } catch (e) {
      if (!mounted) return;
      // Emby answers an unknown account with a bare 500 "NotFound".
      final notFound = e is DioException &&
          e.response?.statusCode == 500 &&
          '${e.response?.data}'.contains('NotFound');
      _snack(notFound
          ? l10n.adminEmbyConnectNotFound
          : l10n.adminFailed(describeError(e, l10n)));
    } finally {
      if (mounted) setState(() => _connectBusy = false);
    }
  }

  bool get _emby => AdminServerScope.isEmby(context);

  /// A policy key only Emby has, shown when the server sent it.
  bool _embyHas(String key) => _emby && _policy.containsKey(key);

  bool get _isSelf => _client.userId == widget.userId;
  bool get _isAdmin => _policy['IsAdministrator'] == true;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminUserLoadFailed,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    final name = '${_profile['Name'] ?? ''}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: adminScreenHeader(
            context,
            title: name.isEmpty ? l10n.adminUserSettings : name,
            icon: Icons.person_outline,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: DetailsTabBar(
            segmented: true,
            wrap: PlatformDetection.useMobileUi,
            labels: [
              l10n.profile,
              l10n.permissions,
              l10n.access,
              l10n.adminParentalControl,
              l10n.password,
            ],
            selectedIndex: _selectedTab,
            onSelect: (i) => setState(() => _selectedTab = i),
            focusNodeFor: _tabNode,
          ),
        ),
        Expanded(
          child: draftKeyed(
            IndexedStack(
              index: _selectedTab,
              children: [
                _tab(_buildProfileTab(l10n)),
                _tab(_buildPermissionsTab(l10n)),
                _tab(_buildAccessTab(l10n)),
                _tab(_buildParentalTab(l10n)),
                _tab(_buildPasswordTab(l10n)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(List<Widget> children) => ListView(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).padding.bottom + 40),
        children: children,
      );

  List<Widget> _buildProfileTab(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return [
      if (_policy['IsDisabled'] == true)
        Card(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.adminUserDisabledBanner,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ),
      adminSection(
        context,
        title: l10n.profile,
        icon: Icons.badge_outlined,
        children: [
          adminFieldRow(
            label: l10n.username,
            child: TextFormField(
              initialValue: '${_profile['Name'] ?? ''}',
              decoration: adminInputDecoration(),
              onChanged: (v) {
                setState(() => _profile['Name'] = v);
                edited();
              },
            ),
          ),
        ],
      ),
      if (_emby) _buildConnectSection(l10n),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showAdminUserDeleteDialog(
            context,
            user: ServerUser(id: widget.userId, name: '${_profile['Name']}'),
            onDeleted: () {
              ref.invalidate(adminUsersListProvider);
              draft?.discard();
              context.go(Destinations.adminUsers);
            },
          ),
          icon: const Icon(Icons.delete),
          label: Text(l10n.adminDeleteUser),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
        ),
      ),
    ];
  }

  Widget _buildConnectSection(AppLocalizations l10n) {
    final linked = _connectLinked.isNotEmpty;
    return adminSection(
      context,
      title: l10n.adminEmbyConnect,
      icon: Icons.link,
      children: [
        adminFieldRow(
          label: l10n.adminEmbyConnectUser,
          helper: linked ? l10n.adminEmbyConnectLinked : l10n.adminEmbyConnectHelp,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _connectController,
                  enabled: !linked && !_connectBusy,
                  decoration: adminInputDecoration(),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _setConnect(link: true),
                ),
              ),
              const SizedBox(width: 8),
              if (linked)
                OutlinedButton(
                  onPressed: _connectBusy ? null : () => _setConnect(link: false),
                  child: Text(l10n.adminEmbyConnectUnlink),
                )
              else
                FilledButton.tonal(
                  onPressed: _connectBusy || _connectController.text.trim().isEmpty
                      ? null
                      : () => _setConnect(link: true),
                  child: Text(l10n.adminEmbyConnectLink),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPermissionsTab(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final auth = _authRows(l10n);
    return [
      adminSection(
        context,
        title: l10n.admin,
        icon: Icons.shield_outlined,
        children: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.adminFullAccessWarning,
                style: TextStyle(color: scheme.error),
              ),
            ),
          _policySwitch('IsAdministrator', l10n.administrator),
          _policySwitch('IsHidden', l10n.adminHiddenUser),
          if (_embyHas('IsHiddenRemotely'))
            _policySwitch('IsHiddenRemotely', l10n.adminHiddenRemotely),
          if (_embyHas('IsHiddenFromUnusedDevices'))
            _policySwitch(
                'IsHiddenFromUnusedDevices', l10n.adminHiddenFromUnusedDevices),
          _policySwitch('IsDisabled', l10n.disabled),
        ],
      ),
      adminSection(
        context,
        title: l10n.playback,
        icon: Icons.play_circle_outline,
        children: [
          _policySwitch('EnableMediaPlayback', l10n.adminAllowMediaPlayback),
          _policySwitch(
              'EnableAudioPlaybackTranscoding', l10n.adminAllowAudioTranscoding),
          _policySwitch(
              'EnableVideoPlaybackTranscoding', l10n.adminAllowVideoTranscoding),
          _policySwitch('EnablePlaybackRemuxing', l10n.adminAllowRemuxing),
          if (!_emby)
            _policySwitch('ForceRemoteSourceTranscoding',
                l10n.adminForceRemoteTranscoding),
          _mbpsField('RemoteClientBitrateLimit', l10n.adminRemoteBitrateLimitMbps,
              l10n.adminLeaveEmptyNoLimit),
          if (_embyHas('AutoRemoteQuality'))
            _mbpsField('AutoRemoteQuality', l10n.adminAutoRemoteQuality,
                l10n.adminAutoRemoteQualityHelp),
          if (_embyHas('SimultaneousStreamLimit')) _streamLimitRow(l10n),
        ],
      ),
      adminSection(
        context,
        title: l10n.content,
        icon: Icons.folder_outlined,
        children: [
          _policySwitch(
              'EnableContentDownloading', l10n.adminAllowContentDownloading),
          _policySwitch('EnablePublicSharing', l10n.adminAllowPublicSharing),
          for (final (key, label) in [
            ('EnableSyncTranscoding', l10n.adminAllowSyncTranscoding),
            ('EnableMediaConversion', l10n.adminAllowMediaConversion),
            ('AllowCameraUpload', l10n.adminAllowCameraUpload),
            ('AllowSharingPersonalItems', l10n.adminAllowSharingPersonalItems),
          ])
            if (_embyHas(key)) _policySwitch(key, label),
        ],
      ),
      // Tortugarr: Download Now within limits for a non-administrator.
      if (!_isAdmin && DownloadFeatures.viaPlugin)
        DownloadLimitsSection(userId: widget.userId),
      adminSection(
        context,
        title: l10n.sessions,
        icon: Icons.devices_outlined,
        children: [
          _policySwitch(
              'EnableRemoteControlOfOtherUsers', l10n.adminAllowRemoteControl),
          _policySwitch(
              'EnableSharedDeviceControl', l10n.adminAllowSharedDeviceControl),
          if (_serverRemoteAccess)
            _policySwitch('EnableRemoteAccess', l10n.adminAllowRemoteAccess),
          if (!_emby)
            _intField('MaxActiveSessions', l10n.adminMaxActiveSessions,
                l10n.adminLeaveEmptyNoLimit),
        ],
      ),
      adminSection(
        context,
        title: l10n.features,
        icon: Icons.tune,
        children: [
          _policySwitch('EnableLiveTvAccess', l10n.adminAllowLiveTvAccess),
          _policySwitch(
              'EnableLiveTvManagement', l10n.adminAllowLiveTvManagement),
          if (!_emby)
            _policySwitch('EnableCollectionManagement',
                l10n.adminAllowCollectionManagement),
          _policySwitch(
              'EnableSubtitleManagement', l10n.adminAllowSubtitleManagement),
          if (_embyHas('EnableSubtitleDownloading'))
            _policySwitch(
                'EnableSubtitleDownloading', l10n.adminAllowSubtitleDownloading),
          if (!_emby)
            _policySwitch(
                'EnableLyricManagement', l10n.adminAllowLyricManagement),
          if (_embyHas('EnableUserPreferenceAccess'))
            _policySwitch(
                'EnableUserPreferenceAccess', l10n.adminAllowPreferenceAccess),
        ],
      ),
      if (auth.isNotEmpty)
        adminSection(
          context,
          title: l10n.authentication,
          icon: Icons.lock_outline,
          children: auth,
        ),
    ];
  }

  /// Emby counts 0 as unlimited. The stored value joins the list in case
  /// it's past 50.
  Widget _streamLimitRow(AppLocalizations l10n) {
    final current = (_policy['SimultaneousStreamLimit'] as num?)?.toInt() ?? 0;
    return adminFieldRow(
      label: l10n.adminStreamingStreamLimit,
      helper: l10n.adminSimultaneousStreamLimitHelp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: current,
            isExpanded: true,
            decoration: adminInputDecoration(),
            items: [
              for (final n in {for (var i = 0; i <= 50; i++) i, current})
                DropdownMenuItem(
                  value: n,
                  child: Text(n == 0 ? l10n.adminUnlimited : '$n'),
                ),
            ],
            onChanged: (v) => _setPolicy('SimultaneousStreamLimit', v ?? 0),
          ),
          const PremiereNote(margin: EdgeInsets.only(top: 8)),
        ],
      ),
    );
  }

  List<Widget> _authRows(AppLocalizations l10n) => [
        if (_authProviders.length > 1)
          _providerDropdown(
            label: l10n.adminAuthProvider,
            policyKey: 'AuthenticationProviderId',
            providers: _authProviders,
          ),
        if (_resetProviders.length > 1)
          _providerDropdown(
            label: l10n.adminPasswordResetProvider,
            policyKey: 'PasswordResetProviderId',
            providers: _resetProviders,
          ),
        if (!_emby) ...[
          _intField('LoginAttemptsBeforeLockout',
              l10n.adminLoginAttemptsBeforeLockout, l10n.adminLoginAttemptsHint),
          adminFieldRow(
            label: l10n.adminSyncPlayAccess,
            child: DropdownButtonFormField<String>(
              initialValue:
                  (_policy['SyncPlayAccess'] as String?) ?? 'CreateAndJoinGroups',
              isExpanded: true,
              decoration: adminInputDecoration(),
              items: [
                DropdownMenuItem(
                  value: 'CreateAndJoinGroups',
                  child: Text(l10n.adminSyncPlayCreateAndJoin),
                ),
                DropdownMenuItem(
                  value: 'JoinGroups',
                  child: Text(l10n.adminSyncPlayJoin),
                ),
                DropdownMenuItem(
                  value: 'None',
                  child: Text(l10n.adminSyncPlayNone),
                ),
              ],
              onChanged: (v) => _setPolicy('SyncPlayAccess', v),
            ),
          ),
        ],
      ];

  static String _mbps(Object? bps) {
    if (bps is! num || bps <= 0) return '';
    final mbps = bps / 1e6;
    return mbps == mbps.roundToDouble()
        ? mbps.toInt().toString()
        : mbps.toString();
  }

  /// Stored in bits per second, and an empty field is 0 (none).
  Widget _mbpsField(String key, String label, String helper) {
    return adminFieldRow(
      label: label,
      helper: helper,
      child: TextFormField(
        initialValue: _mbps(_policy[key]),
        decoration: adminInputDecoration(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) =>
            _setPolicy(key, ((double.tryParse(v.trim()) ?? 0) * 1e6).floor()),
      ),
    );
  }

  /// The server's ints aren't nullable, so an empty field is 0.
  Widget _intField(String key, String label, String helper) {
    return adminFieldRow(
      label: label,
      helper: helper,
      child: TextFormField(
        initialValue: '${_policy[key] ?? ''}',
        decoration: adminInputDecoration(),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        onChanged: (v) => _setPolicy(key, int.tryParse(v.trim()) ?? 0),
      ),
    );
  }

  Widget _providerDropdown({
    required String label,
    required String policyKey,
    required List<Map<String, dynamic>> providers,
  }) {
    final current = _policy[policyKey] as String?;
    final ids = providers
        .map((p) => (p['Id'] ?? p['id'])?.toString())
        .whereType<String>()
        .toList();
    return adminFieldRow(
      label: label,
      child: DropdownButtonFormField<String>(
        initialValue: ids.contains(current)
            ? current
            : (ids.isNotEmpty ? ids.first : null),
        isExpanded: true,
        decoration: adminInputDecoration(),
        items: providers.map((p) {
          final id = (p['Id'] ?? p['id'])?.toString() ?? '';
          final name = (p['Name'] ?? p['name'])?.toString() ?? id;
          return DropdownMenuItem(value: id, child: Text(name));
        }).toList(),
        onChanged: (v) => _setPolicy(policyKey, v),
      ),
    );
  }

  List<Widget> _buildAccessTab(AppLocalizations l10n) {
    String nameOf(Map<String, dynamic> item) => '${item['Name'] ?? item['Id']}';
    return [
      adminSection(
        context,
        title: l10n.adminLibraryAccess,
        icon: Icons.video_library_outlined,
        children: _allOrSome(
          'EnableAllFolders',
          'EnabledFolders',
          l10n.adminEnableAllLibraryAccess,
          [for (final lib in _libraries) (lib.itemId, lib.name)],
        ),
      ),
      if (_channels.isNotEmpty)
        adminSection(
          context,
          title: l10n.adminChannelAccess,
          icon: Icons.live_tv_outlined,
          children: _allOrSome(
            'EnableAllChannels',
            'EnabledChannels',
            l10n.adminEnableAllChannels,
            [for (final c in _channels) ('${c['Id']}', nameOf(c))],
          ),
        ),
      // Administrators sign in from any device, so this is hidden for them.
      if (!_isAdmin)
        adminSection(
          context,
          title: l10n.adminDeviceAccess,
          icon: Icons.devices_outlined,
          children: _allOrSome(
            'EnableAllDevices',
            'EnabledDevices',
            l10n.adminEnableAllDevices,
            // Emby's policy holds the id the client reported.
            [
              for (final d in _devices)
                (d.reportedDeviceId ?? d.id, _deviceLabel(d)),
            ],
          ),
        ),
      adminSection(
        context,
        title: l10n.adminContentDeletionFolders,
        icon: Icons.delete_outline,
        children: _allOrSome(
          'EnableContentDeletion',
          'EnableContentDeletionFromFolders',
          l10n.adminDeleteFromAllLibraries,
          [
            for (final lib in _libraries) (lib.itemId, lib.name),
            for (final c in _deletableChannels) ('${c['Id']}', nameOf(c)),
          ],
        ),
      ),
    ];
  }

  /// `CustomName or Name - AppName`, else the device id.
  static String _deviceLabel(DeviceInfoDto d) {
    final label = [
      d.customName?.isNotEmpty == true ? d.customName : d.name,
      d.appName,
    ].whereType<String>().join(' - ');
    return label.isEmpty ? d.id : label;
  }

  /// An "all" switch and, while it's off, one checkbox per item. Turning it
  /// on empties the list.
  List<Widget> _allOrSome(
    String allKey,
    String listKey,
    String allLabel,
    List<(String, String)> items,
  ) {
    final all = _policy[allKey] == true;
    final selected = _listOf(listKey);
    return [
      adminSwitchRow(
        title: allLabel,
        value: all,
        onChanged: (v) => _editPolicy((p) {
          p[allKey] = v;
          if (v) p[listKey] = <String>[];
        }),
      ),
      if (!all)
        for (final (id, name) in items)
          CheckboxListTile(
            title: Text(name),
            value: selected.contains(id),
            onChanged: (v) => _toggleListMembership(listKey, id, v ?? false),
          ),
    ];
  }

  /// Neighbouring ratings with the same score and sub score are one option,
  /// their names joined with "/".
  static List<_RatingOption> _groupRatings(List<Map<String, dynamic>> raw) {
    final out = <_RatingOption>[];
    for (final r in raw) {
      final name = r['Name']?.toString();
      final ratingScore = r['RatingScore'];
      // Servers before RatingScore only send Value.
      final score = ratingScore is Map
          ? ratingScore['score'] as int?
          : r['Value'] as int?;
      final subScore = ratingScore is Map ? ratingScore['subScore'] as int? : null;
      if (name == null || score == null) continue;
      if (out.isNotEmpty &&
          out.last.score == score &&
          out.last.subScore == subScore) {
        out.last = (
          name: '${out.last.name}/$name',
          score: score,
          subScore: subScore,
        );
      } else {
        out.add((name: name, score: score, subScore: subScore));
      }
    }
    return out;
  }

  /// The exact score and sub score, else the highest score at or below it.
  int? _ratingIndex() {
    final max = _policy['MaxParentalRating'] as int?;
    if (max == null) return null;
    final sub = _policy['MaxParentalSubRating'] as int?;
    final exact = _ratings.lastIndexWhere(
        (o) => o.score == max && o.subScore == sub);
    if (exact != -1) return exact;
    final below = _ratings.lastIndexWhere((o) => o.score <= max);
    return below == -1 ? null : below;
  }

  List<Widget> _buildParentalTab(AppLocalizations l10n) {
    final unratedItems = <(String, String)>[
      ('Book', l10n.adminUnratedBook),
      ('ChannelContent', l10n.adminUnratedChannelContent),
      ('LiveTvChannel', l10n.adminUnratedLiveTvChannel),
      ('Movie', l10n.adminUnratedMovie),
      ('Music', l10n.adminUnratedMusic),
      ('Trailer', l10n.adminUnratedTrailer),
      ('Series', l10n.adminUnratedSeries),
    ];
    final blocked = _listOf('BlockUnratedItems');
    // Emby has one tag list, which allows rather than blocks in this mode.
    final inclusive = _policy['IsTagBlockingModeInclusive'] == true;

    return [
      adminSection(
        context,
        title: l10n.adminMaxParentalRating,
        icon: Icons.family_restroom,
        children: [
          adminFieldRow(
            label: l10n.adminMaxParentalRating,
            helper: l10n.adminMaxParentalRatingHint,
            child: DropdownButtonFormField<int?>(
              initialValue: _ratingIndex(),
              isExpanded: true,
              decoration: adminInputDecoration(),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.adminParentalRatingNone),
                ),
                for (var i = 0; i < _ratings.length; i++)
                  DropdownMenuItem<int?>(value: i, child: Text(_ratings[i].name)),
              ],
              onChanged: (i) => _editPolicy((p) {
                p.remove('MaxParentalRating');
                p.remove('MaxParentalSubRating');
                if (i == null) return;
                p['MaxParentalRating'] = _ratings[i].score;
                if (_ratings[i].subScore != null) {
                  p['MaxParentalSubRating'] = _ratings[i].subScore;
                }
              }),
            ),
          ),
        ],
      ),
      adminSection(
        context,
        title: l10n.adminBlockUnratedItems,
        icon: Icons.block,
        children: [
          for (final (value, label) in unratedItems)
            CheckboxListTile(
              title: Text(label),
              value: blocked.contains(value),
              onChanged: (v) =>
                  _toggleListMembership('BlockUnratedItems', value, v ?? false),
            ),
        ],
      ),
      if (!_emby)
        adminSection(
          context,
          title: l10n.adminAllowedTags,
          icon: Icons.label_outline,
          children: [
            _buildTagEditor('AllowedTags', l10n.adminAllowedTagsHint, l10n),
          ],
        ),
      adminSection(
        context,
        title: inclusive ? l10n.adminAllowedTags : l10n.adminBlockedTags,
        icon: inclusive ? Icons.label_outline : Icons.label_off_outlined,
        children: [
          if (_embyHas('IsTagBlockingModeInclusive'))
            adminFieldRow(
              label: l10n.adminTagMode,
              child: DropdownButtonFormField<bool>(
                initialValue: inclusive,
                isExpanded: true,
                decoration: adminInputDecoration(),
                items: [
                  DropdownMenuItem(
                      value: false, child: Text(l10n.adminBlockedTags)),
                  DropdownMenuItem(
                      value: true, child: Text(l10n.adminAllowedTags)),
                ],
                onChanged: (v) =>
                    _setPolicy('IsTagBlockingModeInclusive', v ?? false),
              ),
            ),
          _buildTagEditor(
            'BlockedTags',
            inclusive ? l10n.adminAllowedTagsHint : l10n.adminBlockedTagsHint,
            l10n,
          ),
        ],
      ),
      if (!_isAdmin)
        adminSection(
          context,
          title: l10n.adminAccessSchedules,
          icon: Icons.schedule,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l10n.adminAccessSchedulesHint,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            ..._buildSchedules(l10n),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _setPolicy('AccessSchedules', [
                    ..._schedules,
                    {'DayOfWeek': 'Everyday', 'StartHour': 0, 'EndHour': 24},
                  ]),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.adminAddSchedule),
                ),
              ),
            ),
          ],
        ),
    ];
  }

  static const List<String> _dayValues = [
    'Everyday',
    'Weekday',
    'Weekend',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String _dayLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'Everyday':
        return l10n.adminDayEveryday;
      case 'Weekday':
        return l10n.adminDayWeekday;
      case 'Weekend':
        return l10n.adminDayWeekend;
      case 'Sunday':
        return l10n.adminDaySunday;
      case 'Monday':
        return l10n.adminDayMonday;
      case 'Tuesday':
        return l10n.adminDayTuesday;
      case 'Wednesday':
        return l10n.adminDayWednesday;
      case 'Thursday':
        return l10n.adminDayThursday;
      case 'Friday':
        return l10n.adminDayFriday;
      case 'Saturday':
        return l10n.adminDaySaturday;
    }
    return value;
  }

  List<Map<String, dynamic>> get _schedules => [
        for (final s in _policy['AccessSchedules'] as List? ?? const [])
          Map<String, dynamic>.from(s as Map),
      ];

  /// The index of the first schedule whose start isn't before its end.
  static int? _badSchedule(Map<String, dynamic> policy) {
    final schedules = policy['AccessSchedules'] as List? ?? const [];
    for (var i = 0; i < schedules.length; i++) {
      final s = schedules[i] as Map;
      if (((s['StartHour'] as num?) ?? 0) >= ((s['EndHour'] as num?) ?? 0)) {
        return i;
      }
    }
    return null;
  }

  List<Widget> _buildSchedules(AppLocalizations l10n) {
    final schedules = _schedules;
    final bad = _badSchedule(_policy);
    return [
      for (var i = 0; i < schedules.length; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _dayValues.contains(schedules[i]['DayOfWeek'])
                      ? schedules[i]['DayOfWeek'] as String
                      : 'Everyday',
                  isExpanded: true,
                  decoration: adminInputDecoration(label: l10n.adminScheduleDay),
                  items: _dayValues
                      .map((d) => DropdownMenuItem(
                          value: d, child: Text(_dayLabel(d, l10n))))
                      .toList(),
                  onChanged: (v) => _updateSchedule(i, 'DayOfWeek', v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _hourDropdown(l10n.adminScheduleStart,
                    schedules[i]['StartHour'], null,
                    (v) => _updateSchedule(i, 'StartHour', v)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _hourDropdown(l10n.adminScheduleEnd,
                    schedules[i]['EndHour'],
                    i == bad ? l10n.adminScheduleStartBeforeEnd : null,
                    (v) => _updateSchedule(i, 'EndHour', v)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    _setPolicy('AccessSchedules', schedules..removeAt(i)),
              ),
            ],
          ),
        ),
    ];
  }

  /// Half hours from 0:00 to 24:00, plus the stored value when it's off that
  /// grid.
  Widget _hourDropdown(
    String label,
    Object? raw,
    String? error,
    ValueChanged<double?> onChanged,
  ) {
    final value = (raw as num? ?? 0).toDouble();
    final hours = {for (var i = 0; i <= 48; i++) i / 2, value}.toList()..sort();
    String text(double h) =>
        '${h.floor().toString().padLeft(2, '0')}:'
        '${((h % 1) * 60).round().toString().padLeft(2, '0')}';
    return DropdownButtonFormField<double>(
      initialValue: value,
      isExpanded: true,
      decoration: adminInputDecoration(label: label)
          .copyWith(errorText: error, errorMaxLines: 3),
      items: [
        for (final h in hours) DropdownMenuItem(value: h, child: Text(text(h))),
      ],
      onChanged: onChanged,
    );
  }

  void _updateSchedule(int index, String key, Object? value) {
    if (value == null) return;
    final schedules = _schedules;
    schedules[index][key] = value;
    _setPolicy('AccessSchedules', schedules);
  }

  Widget _buildTagEditor(String key, String hint, AppLocalizations l10n) {
    final tags = _listOf(key);
    final controller =
        _tagControllers.putIfAbsent(key, () => TextEditingController());
    void addTag() {
      final t = controller.text.trim();
      if (t.isEmpty) return;
      if (!tags.contains(t)) _setPolicy(key, [...tags, t]);
      controller.clear();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in tags)
                  Chip(
                    label: Text(t),
                    onDeleted: () =>
                        _setPolicy(key, tags.where((x) => x != t).toList()),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: adminInputDecoration(hint: l10n.adminAddTag),
                  onSubmitted: (_) => addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: l10n.adminAddTag,
                onPressed: addTag,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPasswordTab(AppLocalizations l10n) {
    Widget field(String label, TextEditingController controller) =>
        adminFieldRow(
          label: label,
          child: TextField(
            controller: controller,
            decoration: adminInputDecoration(),
            obscureText: true,
          ),
        );
    return [
      adminSection(
        context,
        title: l10n.adminChangePassword,
        icon: Icons.password,
        children: [
          // The server checks it when an admin changes their own password.
          if (_isSelf) field(l10n.adminCurrentPassword, _currentPasswordController),
          field(l10n.adminNewPassword, _passwordController),
          field(l10n.adminConfirmPassword, _confirmPasswordController),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: _passwordBusy ? null : _savePassword,
            child: Text(l10n.adminSetPassword),
          ),
          // A reset removes the password, and an administrator can't be left
          // without one.
          if (!_isAdmin)
            OutlinedButton(
              onPressed: _passwordBusy ? null : _resetPassword,
              child: Text(l10n.adminResetPassword),
            ),
        ],
      ),
    ];
  }

  Widget _policySwitch(String key, String label) {
    return adminSwitchRow(
      title: label,
      value: _policy[key] as bool? ?? false,
      onChanged: (v) => _setPolicy(key, v),
    );
  }
}
