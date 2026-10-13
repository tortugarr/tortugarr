import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/achievement_models.dart';
import 'package:moonfin/data/services/achievements_service.dart';
import 'package:server_core/server_core.dart';

import '../../support/achievement_plugin_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AchievementPluginAdapter adapter;
  late AchievementsService service;
  late MockMediaServerClient client;

  setUp(() {
    adapter = AchievementPluginAdapter();
    final dio = Dio();
    dio.httpClientAdapter = adapter;
    service = AchievementsService(dio: dio);
    client = buildAchievementClient();
  });

  group('stats', () {
    test('records, the clock and the server come back together', () async {
      await service.refreshAvailability(client);

      final stats = await service.fetchStats(client);
      expect(stats.records['BestWatchStreak'], 21);
      expect(stats.records['LongestItemMinutes'], 201);
      expect(stats.watchClock[21], 40);
      expect(stats.server?.users, 6);
      expect(stats.server?.mostCommonBadge, 'First Contact');
    });

    test('privacy mode leaves the server figures unasked', () async {
      adapter.forcePrivacyMode = true;
      await service.refreshAvailability(client);

      final stats = await service.fetchStats(client);
      expect(stats.server, isNull);
      expect(stats.records, isNotEmpty);
      expect(
        adapter.requests.any((r) => r.contains('server/stats')),
        isFalse,
      );
    });
  });

  group('activity', () {
    test('the feed comes back newest first', () async {
      await service.refreshAvailability(client);

      final entries = await service.fetchActivity(client);
      expect(entries, hasLength(2));
      expect(entries.first.userName, 'Ada');
      expect(entries.first.badgeTitle, 'First Contact');
      expect(entries.first.rarity, 'Common');
    });

    test('an admin who turned the feed off is not asked for it', () async {
      adapter.activityFeedEnabled = false;
      await service.refreshAvailability(client);

      expect(await service.fetchActivity(client), isEmpty);
      expect(
        adapter.requests.any((r) => r.contains('activity-feed')),
        isFalse,
      );
    });
  });

  group('shop', () {
    test('only the power-ups are read from the catalogue', () async {
      final items = await service.fetchShopPowerUps(client);

      expect(items, hasLength(3));
      expect(items.first.id, 'pu-xp-boost-1');
      expect(items.first.priceScore, 50);
      expect(items[1].bundleSize, 3);
    });

    test('buying deducts from the bank and names the item', () async {
      final result = await service.buy(client, 'pu-xp-boost-3');

      expect(result.outcome, PurchaseOutcome.bought);
      expect(result.bankAfter, 1240 - 130);
      expect(adapter.lastBody, contains('pu-xp-boost-3'));
    });

    test('a bank too short is refused, not broken', () async {
      adapter.scoreBank = 10;

      final result = await service.buy(client, 'pu-streak-freeze-1');
      expect(result.outcome, PurchaseOutcome.refused);
      expect(result.message, 'Not enough score.');
    });

    test('what was bought lands in the inventory', () async {
      await service.buy(client, 'pu-xp-boost-3');

      final state = await service.fetchPowerUps(client);
      expect(state?.slots.firstWhere((s) => s.type == 'XpBoost').count, 5);
    });
  });

  group('loadout', () {
    test('the bank and the inventory come back together', () async {
      final state = await service.fetchPowerUps(client);

      expect(state?.bank, 1240);
      expect(state?.slots, hasLength(3));
      expect(
        state?.slots.firstWhere((s) => s.type == 'XpBoost').count,
        2,
      );
      expect(
        state?.slots.firstWhere((s) => s.type == 'DoubleCredit').count,
        0,
      );
    });

    test('spending one hands back the inventory it left', () async {
      final result = await service.usePowerUp(client, 'XpBoost');

      expect(result.outcome, PowerUpUseOutcome.used);
      expect(
        result.slots.firstWhere((s) => s.type == 'XpBoost').count,
        1,
      );
      expect(
        result.slots.firstWhere((s) => s.type == 'XpBoost').active,
        isTrue,
      );
    });

    test("an empty slot is refused in the plugin's own words", () async {
      final result = await service.usePowerUp(client, 'DoubleCredit');

      expect(result.outcome, PowerUpUseOutcome.refused);
      expect(result.message, 'None left.');
    });
  });

  group('badge suggestions', () {
    test('a badge carries its progress and what to watch', () async {
      final chase = await service.fetchBadgeChase(client, 'binge-titan');

      expect(chase?.current, 4);
      expect(chase?.target, 10);
      expect(chase?.items, hasLength(2));
      expect(chase?.items.first.name, 'Trolls Band Together');
      expect(chase?.items.first.runtimeMinutes, 91);
      expect(chase?.items.first.id, 'item-1');
    });

    test('a badge the plugin cannot recommend for comes back empty', () async {
      adapter.pluginMissing = true;

      expect(await service.fetchBadgeChase(client, 'binge-titan'), isNull);
    });
  });

  group('quest reroll', () {
    test('a reroll swaps the set and spends the allowance', () async {
      final result = await service.rerollQuests(client, weekly: false);

      expect(result.outcome, QuestRerollOutcome.rerolled);
      expect(result.quests.single.title, 'A fresh day');
      expect(result.rerollsLeft, 0);
      expect(
        adapter.requests,
        contains(
          'POST /Plugins/AchievementBadges/users/user1/quests/daily/reroll',
        ),
      );
    });

    test('daily and weekly spend separately', () async {
      await service.rerollQuests(client, weekly: false);

      final weekly = await service.rerollQuests(client, weekly: true);
      expect(weekly.outcome, QuestRerollOutcome.rerolled);
      expect(weekly.quests.single.title, 'A fresh week');
    });

    test('a spent reroll reads as refused rather than broken', () async {
      await service.rerollQuests(client, weekly: false);

      final again = await service.rerollQuests(client, weekly: false);
      expect(again.outcome, QuestRerollOutcome.alreadyUsed);
      expect(again.quests, isEmpty);
    });

    test('the overview carries what is left to spend', () async {
      adapter.weeklyRerollsLeft = 0;

      final overview = await service.loadOverview(client);
      expect(overview?.quests?.dailyRerollsLeft, 1);
      expect(overview?.quests?.weeklyRerollsLeft, 0);
    });
  });

  group('availability', () {
    test(
      'a server running the plugin is available and gets the login ping',
      () async {
        expect(await service.refreshAvailability(client), isTrue);
        expect(service.available, isTrue);

        // The ping is fired without being awaited, so let it land.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          adapter.requests,
          containsAllInOrder([
            'GET /Plugins/AchievementBadges/public-config',
            'POST /Plugins/AchievementBadges/users/user1/login-ping',
          ]),
        );
      },
    );

    test('a server without the plugin stays unavailable', () async {
      adapter.pluginMissing = true;

      expect(await service.refreshAvailability(client), isFalse);
      expect(service.available, isFalse);
      expect(adapter.requests, [
        'GET /Plugins/AchievementBadges/public-config',
      ]);
    });

    test('an Emby server is never probed', () async {
      final emby = buildAchievementClient(serverType: ServerType.emby);

      expect(await service.refreshAvailability(emby), isFalse);
      expect(adapter.requests, isEmpty);
    });

    test(
      'reset clears availability, so it can\'t survive a sign-out',
      () async {
        expect(await service.refreshAvailability(client), isTrue);

        service.reset();

        expect(service.available, isFalse);
      },
    );
  });

  group('overview', () {
    test('reads the plugin\'s PascalCase payloads', () async {
      await service.refreshAvailability(client);
      final overview = await service.loadOverview(client);

      expect(overview, isNotNull);
      expect(overview!.summary?.unlocked, 12);
      expect(overview.summary?.total, 200);
      expect(overview.summary?.bestWatchStreak, 9);
      expect(overview.rank?.tier.name, 'Viewer');
      expect(overview.rank?.nextTier?.name, 'Regular');
      expect(overview.rank?.isTopTier, isFalse);
      expect(overview.badges, hasLength(3));
      expect(overview.equipped, hasLength(1));
      expect(overview.quests?.daily, hasLength(1));
      expect(overview.quests?.weekly, isEmpty);
      expect(overview.leaderboard.single.userName, 'Ada');
      expect(overview.recap?.moviesWatched, 4);
      expect(overview.recap?.topGenres.single.name, 'Drama');
      expect(overview.libraryCompletion, {'Movies': 63, 'Shows': 12});
    });

    test(
      'a locked badge keeps its progress and an unlocked one its date',
      () async {
        await service.refreshAvailability(client);
        final overview = await service.loadOverview(client);

        final unlocked = overview!.badges.firstWhere(
          (b) => b.id == 'first-contact',
        );
        expect(unlocked.unlocked, isTrue);
        expect(unlocked.unlockedAt, isNotNull);
        expect(unlocked.progress, 1);
        expect(unlocked.score, 10);

        final locked = overview.badges.firstWhere((b) => b.id == 'binge-titan');
        expect(locked.unlocked, isFalse);
        // UnlockedAt is absent from the payload, not null.
        expect(locked.unlockedAt, isNull);
        expect(locked.progress, closeTo(0.4, 0.001));
        expect(locked.score, 60);
      },
    );

    test('a masked secret badge is recognized as one', () async {
      await service.refreshAvailability(client);
      final overview = await service.loadOverview(client);

      final secret = overview!.badges.firstWhere((b) => b.id == 'deep-cut');
      expect(secret.isSecret, isTrue);

      // An ordinary locked badge must not read as secret.
      expect(
        overview.badges.firstWhere((b) => b.id == 'binge-titan').isSecret,
        isFalse,
      );
    });

    test('sections the admin switched off are not even requested', () async {
      adapter
        ..leaderboardEnabled = false
        ..questsEnabled = false;
      await service.refreshAvailability(client);
      adapter.requests.clear();

      final overview = await service.loadOverview(client);

      expect(overview!.leaderboardEnabled, isFalse);
      expect(overview.questsEnabled, isFalse);
      expect(overview.quests, isNull);
      expect(overview.leaderboard, isEmpty);
      expect(adapter.requests.where((r) => r.contains('quests')), isEmpty);
      expect(adapter.requests.where((r) => r.contains('leaderboard')), isEmpty);
    });

    test('the catalogue is read once and kept', () async {
      await service.refreshAvailability(client);
      adapter.requests.clear();

      await service.loadOverview(client);
      await service.fetchCosmetics(client);

      expect(
        adapter.requests.where((r) => r.contains('shop/catalog')),
        hasLength(1),
      );
    });

    test('a plugin that answers nothing loads as nothing', () async {
      await service.refreshAvailability(client);
      adapter.pluginMissing = true;

      expect(await service.loadOverview(client), isNull);
    });

    test('a session without a user has nothing to load', () async {
      expect(
        await service.loadOverview(buildAchievementClient(userId: null)),
        isNull,
      );
      expect(adapter.requests, isEmpty);
    });

    test('a trailing slash on the server address doesn\'t double up', () async {
      final slashed = buildAchievementClient(baseUrl: 'http://badges.test/');
      await service.refreshAvailability(slashed);

      expect(
        adapter.requests.first,
        'GET /Plugins/AchievementBadges/public-config',
      );
    });
  });

  group('pickers', () {
    test('a category board carries a value instead of a score', () async {
      await service.refreshAvailability(client);

      final entries = await service.fetchLeaderboard(
        client,
        category: 'movies',
      );

      expect(entries.single.value, 42);
      expect(entries.single.score, isNull);
    });

    test('an empty category asks for the overall board', () async {
      await service.refreshAvailability(client);
      adapter.requests.clear();

      final entries = await service.fetchLeaderboard(client);

      expect(entries.single.score, 430);
      // The login ping can still be in flight, so look at the leaderboard
      // calls rather than at every request made.
      expect(adapter.requests.where((r) => r.contains('leaderboard')), [
        'GET /Plugins/AchievementBadges/leaderboard',
      ]);
    });

    test(
      'the leaderboard isn\'t fetched when the admin turned it off',
      () async {
        adapter.leaderboardEnabled = false;
        await service.refreshAvailability(client);
        adapter.requests.clear();

        expect(await service.fetchLeaderboard(client), isEmpty);
        expect(adapter.requests, isEmpty);
      },
    );

    test('the recap is refetched for the chosen period', () async {
      await service.refreshAvailability(client);

      final recap = await service.fetchRecap(client, 'year');

      expect(recap?.period, 'year');
      expect(recap?.daysWatched, 11);
    });
  });

  group('friends', () {
    test('the list, presence and requests are read', () async {
      await service.refreshAvailability(client);

      final friends = await service.fetchFriends(client);
      expect(friends?.friends.map((f) => f.userName), ['Grace', 'Linus']);
      final grace = friends!.friends.first;
      expect(grace.online, isTrue);
      expect(grace.nowPlaying?.seriesName, 'Severance');
      expect(grace.equipped.single.rarity, 'Epic');
      expect(friends.friends.last.lastWatched?.name, 'Heat');
      expect(friends.incoming.single.userName, 'Margaret');
      expect(friends.isPending('user4'), isTrue);
    });

    test('the badge counts requests and unread messages', () async {
      await service.refreshAvailability(client);
      await service.refreshSocial(client);

      expect(service.incomingRequestCount, 1);
      expect(service.unreadMessageCount, 2);
      expect(service.socialBadgeCount, 3);
    });

    test('nothing is asked when an admin turned friends off', () async {
      adapter.friendsEnabled = false;
      await service.refreshAvailability(client);
      adapter.requests.clear();

      await service.refreshSocial(client);

      expect(service.socialAvailable, isFalse);
      expect(adapter.requests, isEmpty);
    });

    test('accepting moves a request into the friends list', () async {
      await service.refreshAvailability(client);

      final write = await service.acceptFriendRequest(client, 'user4');
      final friends = await service.fetchFriends(client);

      expect(write.ok, isTrue);
      expect(friends?.incoming, isEmpty);
      expect(friends?.isFriend('user4'), isTrue);
    });

    test('people to add come from the plugin directory', () async {
      final users = await service.fetchServerUsers(client);

      final names = users.map((user) => user.userName);
      expect(names, contains('Barbara'));
      expect(names, isNot(contains('Hedy')));
      expect(adapter.requests, isNot(contains('GET /Users')));
    });

    test('a plugin without a directory falls back to /Users', () async {
      adapter.directoryMissing = true;

      final users = await service.fetchServerUsers(client);

      expect(users.map((user) => user.userName), contains('Hedy'));
      expect(adapter.requests.last, 'GET /Users');
    });

    test('ids match with or without dashes', () {
      expect(
        sameUserId(
          '5f2b9c1e-0000-4000-8000-00000000abcd',
          '5F2B9C1E00004000800000000000ABCD',
        ),
        isTrue,
      );
    });
  });

  group('chat', () {
    test('only messages new since the last read raise a banner', () async {
      await service.refreshAvailability(client);
      final banners = <ChatThread>[];
      final sub = service.incomingMessages.listen(banners.add);

      // Two messages were already waiting, which is no news.
      await service.refreshSocial(client);
      adapter.chat.add({
        'id': 'msg-3',
        'fromUserId': 'user2',
        'fromUserName': 'Grace',
        'text': 'Hello?',
        'sentAt': '2026-09-20T18:30:00Z',
      });
      adapter.unread = 3;
      await service.refreshSocial(client);
      await Future<void>.delayed(Duration.zero);

      expect(banners.single.name, 'Grace');
      expect(banners.single.lastMessage, 'Hello?');
      await sub.cancel();
    });

    test('the open chat raises no banner', () async {
      await service.refreshAvailability(client);
      final banners = <ChatThread>[];
      final sub = service.incomingMessages.listen(banners.add);

      await service.refreshSocial(client);
      service.openConversationId = 'conv-grace';
      adapter.unread = 3;
      await service.refreshSocial(client);
      await Future<void>.delayed(Duration.zero);

      expect(banners, isEmpty);
      await sub.cancel();
    });

    test('messages come oldest first, not read by the sender alone', () async {
      await service.refreshAvailability(client);
      adapter.chat.first['readBy'] = {'user2': '2026-09-20T18:00:00Z'};

      final messages = await service.fetchMessages(client, 'conv-grace');

      expect(messages?.map((m) => m.id), ['msg-1', 'msg-2']);
      expect(messages!.first.isRead, isFalse);
      expect(messages.first.sentAt, DateTime.utc(2026, 9, 20, 18).toLocal());
    });

    test('a sent message comes back from the server', () async {
      await service.refreshAvailability(client);

      final write = await service.sendMessage(
        client,
        'conv-grace',
        text: 'On my way',
      );

      expect(write.ok, isTrue);
      expect(write.value?.text, 'On my way');
      expect(jsonDecode(adapter.lastBody!), {'Text': 'On my way'});
    });

    test('a refusal carries the plugin\'s reason', () async {
      await service.refreshAvailability(client);

      final write = await service.sendMessage(
        client,
        'conv-grace',
        text: 'x' * 1001,
      );

      expect(write.ok, isFalse);
      expect(write.message, 'Message exceeds 1000 character limit.');
    });

    test('an edit is a PATCH on the message', () async {
      await service.refreshAvailability(client);

      final write = await service.editMessage(client, 'msg-2', 'Fixed');

      expect(write.value?.text, 'Fixed');
      expect(write.value?.editedAt, isNotNull);
      expect(
        adapter.requests,
        contains('PATCH /Plugins/AchievementBadges/users/user1/messages/msg-2'),
      );
    });

    test('an image is uploaded as a file, then sent by id', () async {
      await service.refreshAvailability(client);

      final upload = await service.uploadAttachment(
        client,
        Uint8List.fromList(utf8.encode('png bytes')),
        fileName: 'cat.png',
        mimeType: 'image/png',
      );
      final write = await service.sendMessage(
        client,
        'conv-grace',
        attachmentId: upload.value,
      );

      expect(upload.value, 'att-1');
      expect(adapter.uploads.single, contains('filename="cat.png"'));
      expect(adapter.uploads.single, contains('png bytes'));
      expect(write.value?.attachmentId, 'att-1');
      expect(await service.fetchAttachment(client, 'att-1'), onePixelPng);
    });

    test('a group needs two friends besides the user', () async {
      await service.refreshAvailability(client);

      final refused = await service.createGroup(
        client,
        title: 'Movie night',
        memberIds: ['user2'],
      );
      final created = await service.createGroup(
        client,
        title: 'Movie night',
        memberIds: ['user2', 'user3'],
      );

      expect(refused.ok, isFalse);
      expect(refused.message, contains('at least 3'));
      expect(created.value?.title, 'Movie night');
      expect(created.value?.isOwner('user1'), isTrue);
    });
  });

  group('privacy', () {
    test('saving keeps the plugin settings it does not own', () async {
      await service.refreshAvailability(client);
      final privacy = await service.fetchSocialPrivacy(client);

      final saved = await service.saveSocialPrivacy(
        client,
        privacy!.copyWith(appearOffline: true),
      );

      expect(saved, isTrue);
      expect(adapter.preferences['AppearOffline'], isTrue);
      expect(adapter.preferences['Language'], 'fr');
      expect(adapter.preferences['MessageNotifications'], isTrue);
    });

    test('blocking shows up in the blocked list', () async {
      await service.refreshAvailability(client);

      await service.setBlocked(client, 'user3', blocked: true);
      expect(await service.fetchBlocked(client), ['user3']);

      await service.setBlocked(client, 'user3', blocked: false);
      expect(await service.fetchBlocked(client), isEmpty);
    });
  });

  group('unlock notifications', () {
    Map<String, dynamic> badge(
      String id,
      String unlockedAt, {
      String rarity = 'Common',
    }) => {
      'Id': id,
      'Title': id,
      'Description': '',
      'Icon': 'bolt',
      'Category': 'Watching',
      'Rarity': rarity,
      'Unlocked': true,
      'UnlockedAt': unlockedAt,
      'CurrentValue': 1,
      'TargetValue': 1,
    };

    Future<List<AchievementUnlocks>> read(int times) async {
      final heard = <AchievementUnlocks>[];
      final sub = service.unlocks.listen(heard.add);
      for (var i = 0; i < times; i++) {
        await service.refreshUnlocks(client);
      }
      await pumpEventQueue();
      await sub.cancel();
      return heard;
    }

    test('the admin switch decides whether they are offered', () async {
      await service.refreshAvailability(client);
      expect(service.unlockToastsAvailable, isTrue);

      adapter.unlockToastsEnabled = false;
      await service.refreshAvailability(client);
      expect(service.unlockToastsAvailable, isFalse);
    });

    test('the first read only records the server clock', () async {
      adapter.unlocks.add(badge('old', '2026-09-30T11:00:00.000+00:00'));
      await service.refreshAvailability(client);

      expect(await read(1), isEmpty);
      expect(adapter.unlockReads.single['deviceId'], 'dev1');

      adapter.unlocks.insert(
        0,
        badge('fresh', '2026-09-30T12:05:00.000+00:00', rarity: 'Epic'),
      );
      adapter.serverNow = '2026-09-30T12:06:00.000+00:00';
      final heard = await read(1);

      expect(heard.single.badges.single.id, 'fresh');
      expect(
        adapter.unlockReads.last['since'],
        '2026-09-30T12:00:00.000+00:00',
      );
    });

    test('an unlock is passed on once', () async {
      await service.refreshAvailability(client);
      await read(1);
      adapter.unlocks.add(badge('fresh', '2026-09-30T12:05:00.000+00:00'));

      // The clock hasn't moved, so both reads see the same unlock.
      final heard = await read(2);

      expect(heard, hasLength(1));
    });

    test('badges under the minimum rarity are left out', () async {
      adapter.preferences['MinimumToastRarity'] = 'epic';
      await service.refreshAvailability(client);
      await read(1);
      adapter.unlocks.addAll([
        badge('rare', '2026-09-30T12:05:00.000+00:00', rarity: 'Rare'),
        badge('legend', '2026-09-30T12:06:00.000+00:00', rarity: 'Legendary'),
      ]);

      final heard = await read(1);

      expect(heard.single.badges.map((b) => b.id), ['legend']);
    });

    test('a failed settings read keeps the unlocks coming', () async {
      await service.refreshAvailability(client);
      await read(1);
      adapter.preferencesFailing = true;
      service.expireUnlockSettings();
      adapter.unlocks.add(badge('fresh', '2026-09-30T12:05:00.000+00:00'));

      final heard = await read(1);

      expect(heard.single.badges.single.id, 'fresh');
    });

    test('turned off, the feed is never asked', () async {
      adapter.preferences['EnableUnlockToasts'] = false;
      await service.refreshAvailability(client);

      expect(await read(2), isEmpty);
      expect(adapter.unlockReads, isEmpty);
    });

    test('grouping and the playback mute come from the plugin', () async {
      adapter.preferences['UnlockToastGrouping'] = 'individual';
      adapter.preferences['MuteToastsDuringPlayback'] = true;
      await service.refreshAvailability(client);
      await read(1);
      adapter.unlocks.add(badge('fresh', '2026-09-30T12:05:00.000+00:00'));

      final unlocks = (await read(1)).single;

      expect(unlocks.grouped, isFalse);
      expect(unlocks.muteDuringPlayback, isTrue);
    });

    test('saving keeps the plugin settings it does not own', () async {
      await service.refreshAvailability(client);

      expect(await service.saveUnlockToasts(client, false), isTrue);

      expect(adapter.preferences['EnableUnlockToasts'], isFalse);
      expect(adapter.preferences['Language'], 'fr');
      expect(adapter.preferences['MessageNotifications'], isTrue);
      expect(service.unlockToastsEnabled, isFalse);
    });
  });

  group('background', () {
    tearDown(() => service.reset());

    test('the badge pauses in the background and catches up', () async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await service.refreshAvailability(client);
      service.startPolling(client);
      expect(service.polling, isTrue);

      // A desktop window without focus is still on screen.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(service.polling, isTrue);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(service.polling, isFalse);

      adapter.requests.clear();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(service.polling, isTrue);
      expect(
        adapter.requests,
        contains('GET /Plugins/AchievementBadges/users/user1/friends'),
      );
    });
  });
}
