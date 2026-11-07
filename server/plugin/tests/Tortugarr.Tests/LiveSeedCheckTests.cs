using System.Buffers.Binary;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-07: live seeders from the trackers, dead torrents marked before the grab.</summary>
public class LiveSeedCheckTests
{
    private const string Hex = "0123456789abcdef0123456789abcdef01234567";

    [Fact]
    public void The_hash_comes_from_the_indexer_or_the_magnet_in_hex_or_base32()
    {
        Assert.Equal(Hex, LiveSeedCheck.HashOf(Hex.ToUpperInvariant(), null));
        Assert.Equal(Hex, LiveSeedCheck.HashOf("", $"magnet:?xt=urn:btih:{Hex}&dn=x"));
        var b32 = "AERUKZ4JVPG66AJDIVTYTK6N54ASGRLH"; // the same 20 bytes in base32
        Assert.Equal(Hex, LiveSeedCheck.HashOf(null, $"magnet:?xt=urn:btih:{b32}"));
        Assert.Null(LiveSeedCheck.HashOf("nope", "http://prowlarr/download/1"));
    }

    [Fact]
    public void Trackers_are_read_from_the_magnet()
    {
        var magnet = $"magnet:?xt=urn:btih:{Hex}&dn=Dune&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce"
                     + "&tr=http%3A%2F%2Ftracker.example.org%3A80%2Fannounce&tr=wss%3A%2F%2Fweb.example%3A443&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce";
        Assert.Equal(new[] { "udp://tracker.opentrackr.org:1337/announce", "http://tracker.example.org:80/announce" },
            LiveSeedCheck.TrackersOf(magnet));
        Assert.Empty(LiveSeedCheck.TrackersOf("http://prowlarr/download/1"));
    }

    [Fact]
    public void Udp_packets_follow_bep_15()
    {
        var connect = LiveSeedCheck.ConnectRequest(7);
        Assert.Equal(0x41727101980, BinaryPrimitives.ReadInt64BigEndian(connect));
        Assert.Equal(7, BinaryPrimitives.ReadInt32BigEndian(connect.AsSpan(12)));

        var answer = new byte[16];
        BinaryPrimitives.WriteInt32BigEndian(answer.AsSpan(4), 7);
        BinaryPrimitives.WriteInt64BigEndian(answer.AsSpan(8), 99);
        Assert.Equal(99, LiveSeedCheck.ParseConnect(answer, 7));
        Assert.Null(LiveSeedCheck.ParseConnect(answer, 8));

        var scrape = LiveSeedCheck.ScrapeRequest(99, 5, new[] { LiveSeedCheck.HexToBytes(Hex) });
        Assert.Equal(36, scrape.Length);
        Assert.Equal(2, BinaryPrimitives.ReadInt32BigEndian(scrape.AsSpan(8)));

        var reply = new byte[20];
        BinaryPrimitives.WriteInt32BigEndian(reply, 2);
        BinaryPrimitives.WriteInt32BigEndian(reply.AsSpan(4), 5);
        BinaryPrimitives.WriteInt32BigEndian(reply.AsSpan(8), 468);
        BinaryPrimitives.WriteInt32BigEndian(reply.AsSpan(12), 1000);
        BinaryPrimitives.WriteInt32BigEndian(reply.AsSpan(16), 12);
        Assert.Equal((468, 1000, 12), Assert.Single(LiveSeedCheck.ParseScrape(reply, 5, 1)!));
    }

    [Fact]
    public void Http_scrape_url_and_answer()
    {
        Assert.Equal("http://t.example:80/scrape", LiveSeedCheck.ScrapeUrl("http://t.example:80/announce"));
        Assert.Equal("http://t.example/x/scrape.php?passkey=1", LiveSeedCheck.ScrapeUrl("http://t.example/x/announce.php?passkey=1"));
        Assert.Null(LiveSeedCheck.ScrapeUrl("http://t.example/tracker"));

        var raw = LiveSeedCheck.HexToBytes(Hex);
        var body = new List<byte>();
        body.AddRange(Encoding.ASCII.GetBytes("d5:filesd20:"));
        body.AddRange(raw);
        body.AddRange(Encoding.ASCII.GetBytes("d8:completei42e10:downloadedi9e10:incompletei3eeee"));
        var parsed = LiveSeedCheck.ParseHttpScrape(body.ToArray());
        Assert.Equal((42, 3), parsed[Hex]);
    }

    private static Dictionary<string, LiveSeedCheck.Answer> Live(int seeders, bool own) =>
        new() { [Hex] = new LiveSeedCheck.Answer { Seeders = seeders, OwnTrackerAnswered = own } };

    [Fact]
    public void Only_the_torrents_own_trackers_can_call_it_dead()
    {
        Assert.Equal((0, true), TortugarrService.LiveOf(Live(0, own: true), Hex, "", "Dune.2024.1080p", "1337x"));
        Assert.Equal((0, false), TortugarrService.LiveOf(Live(0, own: false), Hex, "", "Dune.2024.1080p", "1337x"));
        Assert.Equal((55, false), TortugarrService.LiveOf(Live(55, own: true), Hex, "", "Dune.2024.1080p", "1337x"));
        Assert.Equal((null, false), TortugarrService.LiveOf(Live(0, own: true), "", "", "no hash", "x"));
    }

    [Fact]
    public void An_old_rarbg_release_without_live_seeders_is_dead()
    {
        Assert.True(TortugarrService.LiveOf(Live(0, own: false), Hex, "", "Dune.2021.1080p.WEBRip.x264-RARBG", "TPB").Dead);
        Assert.False(TortugarrService.LiveOf(Live(12, own: false), Hex, "", "Dune.2021.1080p.WEBRip.x264-RARBG", "TPB").Dead);
    }

    private static ReleaseDto R(string title, int seeders, string hash, double gb = 6) => new()
    {
        Guid = title, Title = title, Seeders = seeders, InfoHash = hash, Protocol = "torrent", Size = (long)(gb * (1L << 30)),
    };

    [Fact]
    public void Dead_releases_go_last_and_live_numbers_replace_the_indexers()
    {
        var other = "fedcba9876543210fedcba9876543210fedcba98";
        var list = new List<ReleaseDto> { R("dead", 900, Hex), R("alive", 3, other), R("unchecked", 50, "") };
        var live = new Dictionary<string, LiveSeedCheck.Answer>
        {
            [Hex] = new() { Seeders = 0, OwnTrackerAnswered = true },
            [other] = new() { Seeders = 120 },
        };
        TortugarrService.ApplyLive(list, live);
        Assert.Equal(new[] { "alive", "unchecked", "dead" }, list.Select(r => r.Title));
        Assert.Equal(120, list[0].LiveSeeders);
        Assert.Null(list[1].LiveSeeders);
        Assert.True(list[2].Dead);
    }

    [Fact]
    public void The_replacement_trusts_live_seeders_and_skips_dead_ones()
    {
        var a = R("indexer-says-900", 900, Hex);
        a.LiveSeeders = 0;
        a.Dead = true;
        var b = R("indexer-says-3", 3, "");
        b.LiveSeeders = 150;
        var c = R("plain", 40, "");
        Assert.Equal("indexer-says-3", TortugarrService.PickReplacement(new[] { a, b, c }, 6L << 30)?.Title);
    }

    [Fact]
    public async Task A_udp_tracker_is_asked_for_many_hashes_at_once()
    {
        using var tracker = new UdpClient(new IPEndPoint(IPAddress.Loopback, 0));
        var port = ((IPEndPoint)tracker.Client.LocalEndPoint!).Port;
        var serve = Task.Run(async () =>
        {
            var c = await tracker.ReceiveAsync();
            var reply = new byte[16];
            Buffer.BlockCopy(c.Buffer, 12, reply, 4, 4); // transaction id
            BinaryPrimitives.WriteInt64BigEndian(reply.AsSpan(8), 4242);
            await tracker.SendAsync(reply, c.RemoteEndPoint);

            var s = await tracker.ReceiveAsync();
            Assert.Equal(4242, BinaryPrimitives.ReadInt64BigEndian(s.Buffer));
            var n = (s.Buffer.Length - 16) / 20;
            var answer = new byte[8 + (12 * n)];
            BinaryPrimitives.WriteInt32BigEndian(answer, 2);
            Buffer.BlockCopy(s.Buffer, 12, answer, 4, 4);
            for (var i = 0; i < n; i++)
            {
                BinaryPrimitives.WriteInt32BigEndian(answer.AsSpan(8 + (12 * i)), i == 0 ? 0 : 77);
            }

            await tracker.SendAsync(answer, s.RemoteEndPoint);
        });

        var own = $"udp://127.0.0.1:{port}/announce";
        var other = "fedcba9876543210fedcba9876543210fedcba98";
        var check = new LiveSeedCheck(new HttpClient(), NullLogger.Instance);
        var got = await check.CheckAsync(
            new[] { new LiveSeedCheck.Item(Hex, new[] { own }), new LiveSeedCheck.Item(other, new[] { own }) },
            TimeSpan.FromSeconds(3), CancellationToken.None, publicTrackers: Array.Empty<string>());
        await serve;

        Assert.Equal(0, got[Hex].Seeders);
        Assert.True(got[Hex].OwnTrackerAnswered);
        Assert.Equal(77, got[other].Seeders);
    }

    [Fact]
    public async Task A_tracker_that_never_answers_only_costs_the_time_budget()
    {
        using var silent = new UdpClient(new IPEndPoint(IPAddress.Loopback, 0));
        var port = ((IPEndPoint)silent.Client.LocalEndPoint!).Port;
        var check = new LiveSeedCheck(new HttpClient(), NullLogger.Instance);
        var watch = System.Diagnostics.Stopwatch.StartNew();
        var got = await check.CheckAsync(new[] { new LiveSeedCheck.Item(Hex, new[] { $"udp://127.0.0.1:{port}/announce" }) },
            TimeSpan.FromMilliseconds(500), CancellationToken.None, publicTrackers: Array.Empty<string>());
        Assert.Empty(got);
        Assert.True(watch.Elapsed < TimeSpan.FromSeconds(3), watch.Elapsed.ToString());
    }

    private static JsonArray Magnet(string state = "metaDL") => new()
    {
        new JsonObject
        {
            ["hash"] = "42e4fa93", ["name"] = "dune", ["state"] = state, ["progress"] = 0.0,
            ["amount_left"] = 0, ["size"] = 0, ["completion_on"] = -1, ["force_start"] = false, ["category"] = "radarr",
        },
    };

    [Fact]
    public void A_magnet_without_metadata_is_given_up_after_30_minutes()
    {
        var tracks = new Dictionary<string, StallTrack>();
        QbitWatchdog.DecideStalls(Magnet(), tracks, DateTimeOffset.UnixEpoch);
        Assert.Equal(new[] { "42e4fa93" }, QbitWatchdog.DecideStalls(Magnet(), tracks, DateTimeOffset.UnixEpoch.AddMinutes(1)).Reannounce);
        Assert.Empty(QbitWatchdog.DecideStalls(Magnet(), tracks, DateTimeOffset.UnixEpoch.AddMinutes(29.5)).GiveUp);
        Assert.Single(QbitWatchdog.DecideStalls(Magnet(), tracks, DateTimeOffset.UnixEpoch.AddMinutes(30)).GiveUp);
    }

    [Fact]
    public void A_forced_magnet_is_left_alone()
    {
        var tracks = new Dictionary<string, StallTrack>();
        var forced = Magnet();
        forced[0]!["force_start"] = true;
        for (var m = 0; m <= 60; m += 3)
        {
            var plan = QbitWatchdog.DecideStalls(forced, tracks, DateTimeOffset.UnixEpoch.AddMinutes(m));
            Assert.Empty(plan.GiveUp);
            Assert.Empty(plan.Reannounce);
        }
    }
}
