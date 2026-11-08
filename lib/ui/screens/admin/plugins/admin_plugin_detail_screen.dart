import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_nav.dart';
import '../admin_plugin_version_utils.dart';
import '../../../widgets/adaptive/adaptive_dialog.dart';
import '../providers/admin_user_providers.dart';
import '../widgets/admin_form_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../util/error_message.dart';
import '../../../../util/platform_detection.dart';
import 'admin_plugin_install_confirm.dart';
import 'plugin_settings_web_screen.dart';

final _packageInfoProvider = FutureProvider.family<PackageInfo?, String>((
  ref,
  pluginId,
) async {
  final client = GetIt.instance<MediaServerClient>();
  try {
    final packages = await client.adminPluginsApi.getAvailablePackages();
    for (final pkg in packages) {
      if (pkg.id == pluginId) return pkg;
    }
    return null;
  } catch (_) {
    return null;
  }
});

/// A failed lookup only hides the Settings entries.
final _configurationPagesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await GetIt.instance<MediaServerClient>()
        .adminPluginsApi
        .getConfigurationPages();
  } catch (_) {
    return const [];
  }
});

/// The settings page to open for [pluginId]: the plugin's main-menu page,
/// else its first one.
String? configurationPageFor(
  List<Map<String, dynamic>> pages,
  String pluginId,
) {
  Map<String, dynamic>? page;
  for (final candidate in pages) {
    if ('${candidate['PluginId']}'.toLowerCase() != pluginId.toLowerCase()) {
      continue;
    }
    page ??= candidate;
    if (candidate['EnableInMainMenu'] == true) {
      page = candidate;
      break;
    }
  }
  final name = (page?['Name'] ?? '').toString().trim();
  return name.isEmpty ? null : name;
}

/// Emby sends no CanUninstall since any plugin can be removed, and none can
/// be turned off.
bool canUninstallPlugin(BuildContext context, PluginInfo plugin) =>
    plugin.canUninstall || AdminServerScope.isEmby(context);

bool canTogglePlugin(BuildContext context, PluginInfo plugin) =>
    plugin.canUninstall && !AdminServerScope.isEmby(context);

/// Emby's image for a plugin, keyed by its tag, or null without one.
String? pluginThumbUrl(String baseUrl, PluginInfo plugin) {
  final tag = plugin.imageTag;
  if (tag == null) return null;
  return '$baseUrl/Plugins/${Uri.encodeComponent(plugin.id)}/Thumb'
      '?tag=${Uri.encodeQueryComponent(tag)}';
}

/// A plugin's settings page is the server's own web client. On Android and
/// iOS it opens in an in-app web view signed in with the app's session; on
/// desktop (and for Emby) in the browser.
Future<void> openPluginSettingsPage(
  BuildContext context,
  String pageName,
) async {
  // Concatenated rather than resolved, which keeps a reverse proxy's base
  // path such as `https://host/jellyfin`.
  final base = GetIt.instance<MediaServerClient>().baseUrl;
  final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final name = Uri.encodeComponent(pageName);
  final uri = Uri.parse(
    AdminServerScope.isEmby(context)
        ? '$root/web/index.html#!/configurationpage?name=$name'
        : '$root/web/#/configurationpage?name=$name',
  );
  // On Android and iOS the page opens inside the app, signed in with the app's
  // session; the TV's browser asked first and then needed its own sign-in
  // (2026-11-08). Desktop and Emby keep the browser.
  final client = GetIt.instance<MediaServerClient>();
  final token = client.accessToken;
  final userId = client.userId;
  if ((PlatformDetection.isAndroid || PlatformDetection.isIOS) &&
      !AdminServerScope.isEmby(context) &&
      token != null &&
      userId != null) {
    String serverId = '';
    try {
      serverId = '${(await client.systemApi.getSystemInfo())['Id'] ?? ''}';
    } catch (_) {}
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => PluginSettingsWebScreen(
        title: pageName,
        url: uri,
        credentials: PluginSettingsWebScreen.credentialsFor(
          serverAddress: root,
          serverId: serverId,
          userId: userId,
          accessToken: token,
        ),
      ),
    ));
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).adminCouldNotOpenUrl(uri.toString()),
        ),
      ),
    );
  }
}

class AdminPluginDetailScreen extends ConsumerStatefulWidget {
  final String pluginId;
  const AdminPluginDetailScreen({super.key, required this.pluginId});

  @override
  ConsumerState<AdminPluginDetailScreen> createState() =>
      _AdminPluginDetailScreenState();
}

class _AdminPluginDetailScreenState
    extends ConsumerState<AdminPluginDetailScreen> {
  bool _toggling = false;

  AdminPluginsApi get _api =>
      GetIt.instance<MediaServerClient>().adminPluginsApi;

  PluginInfo? _findPlugin(List<PluginInfo> plugins) {
    for (final p in plugins) {
      if (p.id == widget.pluginId) return p;
    }
    return null;
  }

  Future<void> _togglePlugin(PluginInfo plugin) async {
    setState(() => _toggling = true);
    try {
      if (plugin.status == PluginStatus.disabled) {
        await _api.enablePlugin(plugin.id, plugin.version);
      } else {
        await _api.disablePlugin(plugin.id, plugin.version);
      }
      ref.invalidate(adminInstalledPluginsProvider);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final message = switch (e) {
          DioException(response: final response)
              when response?.statusCode == 404 =>
            l10n.adminPluginDetailToggle404,
          DioException() => l10n.adminPluginDetailToggleDioError,
          _ => l10n.adminPluginToggleFailed(describeError(e, l10n)),
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _uninstallPlugin(PluginInfo plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(AppLocalizations.of(context).adminUninstallPlugin),
        content: Text(
          AppLocalizations.of(context).adminUninstallPluginConfirm(plugin.name),
        ),
        actions: [
          adaptiveDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).uninstall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api.uninstallPlugin(plugin.id, plugin.version);
      ref.invalidate(adminInstalledPluginsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).adminPluginRemoveAfterRestart(plugin.name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminPluginUninstallFailed(describeError(e, l10n)))),
        );
      }
    }
  }

  Future<void> _installPluginUpdate(
    PluginInfo plugin,
    PackageInfo package,
    VersionInfo version,
  ) async {
    if (!await confirmPluginInstall(context, version) || !mounted) return;
    try {
      await _api.installPackage(
        package.name,
        assemblyGuid: package.id,
        version: version.version,
        repositoryUrl: version.repositoryUrl.isNotEmpty
            ? version.repositoryUrl
            : null,
        updateClass: version.classification,
      );

      ref.invalidate(adminInstalledPluginsProvider);
      ref.invalidate(adminAvailablePackagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).adminPluginUpdating(plugin.name, version.version),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminPluginUpdateFailed(describeError(e, l10n)))),
        );
      }
    }
  }

  String _pluginImageUrl(PluginInfo plugin) {
    final client = GetIt.instance<MediaServerClient>();
    return pluginThumbUrl(client.baseUrl, plugin) ??
        '${client.baseUrl}/Plugins/${plugin.id}/${plugin.version}/Image';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pluginsAsync = ref.watch(adminInstalledPluginsProvider);
    final packageInfoAsync = ref.watch(_packageInfoProvider(widget.pluginId));
    final configPages =
        ref.watch(_configurationPagesProvider).valueOrNull ?? const [];

    return pluginsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminPluginLoadFailed(describeError(error, l10n))),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminInstalledPluginsProvider),
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
      data: (plugins) {
        final plugin = _findPlugin(plugins);
        if (plugin == null) {
          return Center(
            child: Text(AppLocalizations.of(context).adminPluginNotFound),
          );
        }
        final packageInfo = packageInfoAsync.valueOrNull;
        return _buildContent(
          context,
          plugin,
          packageInfo,
          configurationPageFor(configPages, plugin.id),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    PluginInfo plugin,
    PackageInfo? packageInfo,
    String? configPage,
  ) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final latestUpdateVersion = packageInfo == null || plugin.version.isEmpty
        ? null
        : latestVersionInfoAfter(plugin.version, packageInfo.versions);

    final statusBanner = _buildStatusBanner(context, plugin);

    if (isWide) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          adminScreenHeader(
            context,
            title: plugin.name,
            subtitle: AppLocalizations.of(context)
                .adminPluginVersion(plugin.version),
            icon: Icons.extension_outlined,
          ),
          if (statusBanner != null) ...[
            statusBanner,
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (packageInfo?.description.isNotEmpty == true ||
                        plugin.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        packageInfo?.description ?? plugin.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (packageInfo != null &&
                        packageInfo.versions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _RevisionHistory(
                        versions: packageInfo.versions,
                        installedVersion: plugin.version,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _PluginImage(
                      imageUrl: plugin.hasImage
                          ? _pluginImageUrl(plugin)
                          : packageInfo?.imageUrl,
                    ),
                    const SizedBox(height: 16),
                    // Bundled plugins have no actions but keep their Settings.
                    if (canUninstallPlugin(context, plugin) ||
                        configPage != null) ...[
                      _ActionsSection(
                        plugin: plugin,
                        toggling: _toggling,
                        latestUpdateVersion: latestUpdateVersion?.version,
                        onToggle: () => _togglePlugin(plugin),
                        onInstallUpdate:
                            latestUpdateVersion == null || packageInfo == null
                            ? null
                            : () => _installPluginUpdate(
                                plugin,
                                packageInfo,
                                latestUpdateVersion,
                              ),
                        onUninstall: () => _uninstallPlugin(plugin),
                        onOpenHtmlSettings: configPage == null
                            ? null
                            : () => openPluginSettingsPage(context, configPage),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _DetailsTable(plugin: plugin, packageInfo: packageInfo),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PluginImage(
              imageUrl: plugin.hasImage
                  ? _pluginImageUrl(plugin)
                  : packageInfo?.imageUrl,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: adminScreenHeader(
                context,
                title: plugin.name,
                subtitle: AppLocalizations.of(
                  context,
                ).adminPluginVersion(plugin.version),
              ),
            ),
          ],
        ),
        if (statusBanner != null) ...[
          const SizedBox(height: 4),
          statusBanner,
        ],

        if (packageInfo?.description.isNotEmpty == true ||
            plugin.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            packageInfo?.description ?? plugin.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        if (canUninstallPlugin(context, plugin) || configPage != null) ...[
          const SizedBox(height: 16),
          _ActionsSection(
            plugin: plugin,
            toggling: _toggling,
            latestUpdateVersion: latestUpdateVersion?.version,
            onToggle: () => _togglePlugin(plugin),
            onInstallUpdate: latestUpdateVersion == null || packageInfo == null
                ? null
                : () => _installPluginUpdate(
                    plugin,
                    packageInfo,
                    latestUpdateVersion,
                  ),
            onUninstall: () => _uninstallPlugin(plugin),
            onOpenHtmlSettings: configPage == null
                ? null
                : () => openPluginSettingsPage(context, configPage),
          ),
        ],

        const SizedBox(height: 16),
        _DetailsTable(plugin: plugin, packageInfo: packageInfo),

        if (packageInfo != null && packageInfo.versions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _RevisionHistory(
            versions: packageInfo.versions,
            installedVersion: plugin.version,
          ),
        ],
      ],
    );
  }

  Widget? _buildStatusBanner(BuildContext context, PluginInfo plugin) {
    final theme = Theme.of(context);
    String? message;
    Color? color;

    switch (plugin.status) {
      case PluginStatus.restart:
        message = AppLocalizations.of(context).adminPluginDetailRestartRequired;
        color = theme.colorScheme.tertiary;
      case PluginStatus.deleted:
        message = AppLocalizations.of(context).adminPluginDetailRemovalPending;
        color = theme.colorScheme.error;
      case PluginStatus.malfunctioned:
        message = AppLocalizations.of(context).adminPluginDetailMalfunctioned;
        color = theme.colorScheme.error;
      case PluginStatus.notSupported:
        message = AppLocalizations.of(context).adminPluginDetailNotSupported;
        color = theme.colorScheme.error;
      case PluginStatus.superseded:
        message = AppLocalizations.of(context).adminPluginDetailSuperseded;
        color = theme.colorScheme.tertiary;
      default:
        return null;
    }

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _PluginImage({this.imageUrl, this.size = 120});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return _fallback(context);
    return ClipRRect(
      borderRadius: AppRadius.circular(12),
      child: Image.network(
        imageUrl!,
        headers: serverImageHeaders,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.circular(12),
      ),
      child: Icon(
        Icons.extension,
        size: size * 0.45,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final PluginInfo plugin;
  final bool toggling;
  final String? latestUpdateVersion;
  final VoidCallback onToggle;
  final VoidCallback? onInstallUpdate;
  final VoidCallback onUninstall;
  final VoidCallback? onOpenHtmlSettings;

  const _ActionsSection({
    required this.plugin,
    required this.toggling,
    this.latestUpdateVersion,
    required this.onToggle,
    this.onInstallUpdate,
    required this.onUninstall,
    this.onOpenHtmlSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRestartPending = plugin.status == PluginStatus.restart;
    final canUninstall = canUninstallPlugin(context, plugin);

    return adminGlassGroup(
      context,
      children: [
        if (canTogglePlugin(context, plugin))
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              AppLocalizations.of(context).adminPluginDetailEnablePlugin,
            ),
            value: plugin.status != PluginStatus.disabled,
            onChanged:
                (isRestartPending || toggling) ? null : (_) => onToggle(),
          ),
        if (canUninstall &&
            !PlatformDetection.isTV &&
            onInstallUpdate != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.download, color: theme.colorScheme.primary),
            title: Text(
              latestUpdateVersion != null
                  ? AppLocalizations.of(
                      context,
                    ).adminPluginsInstallUpdateVersioned(
                      latestUpdateVersion!,
                    )
                  : AppLocalizations.of(context).adminPluginsInstallUpdate,
            ),
            onTap: onInstallUpdate,
          ),
        if (onOpenHtmlSettings != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.web, color: theme.colorScheme.primary),
            title: Text(AppLocalizations.of(context).settings),
            subtitle: Text(
              AppLocalizations.of(context).adminPluginSettingsPage,
            ),
            onTap: onOpenHtmlSettings,
          ),
        if (canUninstall)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
            ),
            title: Text(
              AppLocalizations.of(context).uninstall,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: onUninstall,
          ),
      ],
    );
  }
}

class _DetailsTable extends StatelessWidget {
  final PluginInfo plugin;
  final PackageInfo? packageInfo;

  const _DetailsTable({required this.plugin, this.packageInfo});

  @override
  Widget build(BuildContext context) {
    final developer = packageInfo?.owner;
    final repoName = packageInfo?.versions.isNotEmpty == true
        ? packageInfo!.versions.first.repositoryName
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        adminSectionLabel(
            context, AppLocalizations.of(context).adminPluginDetailDetails,
            icon: Icons.info_outline),
        adminGlassGroup(
          context,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(
                    context,
                    AppLocalizations.of(context).status,
                    plugin.status.label,
                  ),
                  _row(context, 'Version', plugin.version),
                  // Emby's catalog names no developers and has no
                  // repositories.
                  if (!AdminServerScope.isEmby(context)) ...[
                    _row(
                      context,
                      AppLocalizations.of(context).adminPluginDetailDeveloper,
                      developer ?? AppLocalizations.of(context).unknown,
                    ),
                    _row(
                      context,
                      AppLocalizations.of(context).adminPluginDetailRepository,
                      plugin.canUninstall
                          ? (repoName ?? AppLocalizations.of(context).unknown)
                          : AppLocalizations.of(context)
                              .adminPluginDetailBundled,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _RevisionHistory extends StatelessWidget {
  final List<VersionInfo> versions;
  final String installedVersion;

  const _RevisionHistory({
    required this.versions,
    required this.installedVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        adminSectionLabel(
            context, AppLocalizations.of(context).adminRevisionHistory,
            icon: Icons.history),
        adminGlassGroup(
          context,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            ...versions.take(10).map((v) {
              final isInstalled = v.version == installedVersion;
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Text(
                      v.version,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isInstalled
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isInstalled) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          AppLocalizations.of(context).adminPluginsInstalled,
                        ),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
                subtitle: v.timestamp != null
                    ? Text(v.timestamp!, style: theme.textTheme.bodySmall)
                    : null,
                children: [
                  if (v.changelog != null && v.changelog!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          v.changelog!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 12),
                      child: Text(
                        AppLocalizations.of(context).adminNoChangelog,
                      ),
                    ),
                ],
              );
            }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
