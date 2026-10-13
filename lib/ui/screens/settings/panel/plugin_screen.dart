part of '../settings_side_panel.dart';

class _PluginScreen extends StatefulWidget {
  const _PluginScreen();

  @override
  State<_PluginScreen> createState() => _PluginScreenState();
}

class _PluginScreenState extends State<_PluginScreen> {
  final _pluginScope = FocusScopeNode(
    debugLabel: 'PluginSettingsScope',
    traversalEdgeBehavior: TraversalEdgeBehavior.stop,
  );
  final _scrollController = ScrollController();
  final _refreshFocusNode = FocusNode(debugLabel: 'PluginRefreshButton');

  @override
  void initState() {
    super.initState();
    _refreshFocusNode.addListener(_onRefreshFocusChange);
  }

  @override
  void dispose() {
    _refreshFocusNode.removeListener(_onRefreshFocusChange);
    _refreshFocusNode.dispose();
    _scrollController.dispose();
    _pluginScope.dispose();
    super.dispose();
  }

  void _onRefreshFocusChange() {
    if (_refreshFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return withCleanSettingsTypography(
      context,
      Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return FocusScope(
            node: _pluginScope,
            autofocus: true,
            child: Scaffold(
              appBar: buildSettingsAppBar(
                context,
                Text(l10n.settingsSync),
                actions: [
                  IconButton(
                    focusNode: _refreshFocusNode,
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      if (GetIt.instance.isRegistered<MediaServerClient>()) {
                        final client = GetIt.instance<MediaServerClient>();
                        final syncService = GetIt.instance<PluginSyncService>();
                        await syncService.refreshAvailability(client);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                syncService.pluginAvailable
                                    ? l10n.pluginDetected
                                    : l10n.pluginNotDetected,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              body: ListView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  bottom: 48 + MediaQuery.paddingOf(context).bottom,
                ),
                children: const [PluginSettingsSection()],
              ),
            ),
          );
        },
      ),
    );
  }
}
