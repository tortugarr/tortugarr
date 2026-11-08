using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>
/// Against real clients, only when TG_LIVE_TRANSMISSION / TG_LIVE_DELUGE point at one (throwaway
/// containers): add a magnet, see it listed, stop, start, reannounce, delete.
/// </summary>
public class TorrentClientLiveTests
{
    private const string Magnet = "magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10&dn=Sintel&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337";
    private const string Hash = "08ada5a7a6183aae1e09d831df6748d566095a10";

    public static IEnumerable<object[]> Clients() => new[]
    {
        new object[] { "transmission", Environment.GetEnvironmentVariable("TG_LIVE_TRANSMISSION") ?? string.Empty, "/config/tg-test" },
        new object[] { "deluge", Environment.GetEnvironmentVariable("TG_LIVE_DELUGE") ?? string.Empty, "/downloads" },
    };

    [Theory]
    [MemberData(nameof(Clients))]
    public async Task A_real_client_does_the_whole_round(string kind, string url, string dir)
    {
        if (string.IsNullOrEmpty(url))
        {
            return; // not configured: skipped
        }

        var c = TorrentClient.Create(new HttpClient { Timeout = TimeSpan.FromSeconds(30) }, kind, url, string.Empty, string.Empty);
        var ct = CancellationToken.None;
        Assert.False(string.IsNullOrWhiteSpace(await c.Version(ct)));
        await c.Add(Magnet, "radarr", dir, ct);
        System.Text.Json.Nodes.JsonNode? t = null;
        for (var i = 0; i < 20 && t is null; i++)
        {
            await Task.Delay(500);
            t = (await c.ListAll(ct)).FirstOrDefault(x => (string?)x?["hash"] == Hash);
        }

        Assert.NotNull(t);
        Assert.Contains((string?)t!["state"], new[] { "metaDL", "downloading", "stalledDL", "queuedDL", "checkingDL" });
        Assert.Single(await c.List("radarr", ct), x => (string?)x?["hash"] == Hash);
        await c.Reannounce(new[] { Hash }, ct);
        await c.Stop(new[] { Hash }, ct);
        await Task.Delay(1500);
        Assert.Equal("stoppedDL", (string?)(await c.ListAll(ct)).First(x => (string?)x?["hash"] == Hash)!["state"]);
        await c.Start(new[] { Hash }, ct);
        await Task.Delay(1500);
        Assert.NotEqual("stoppedDL", (string?)(await c.ListAll(ct)).First(x => (string?)x?["hash"] == Hash)!["state"]);
        Assert.NotNull(await c.FreeSpace(ct));
        await c.Delete(Hash, true, ct);
        await Task.Delay(1500);
        Assert.DoesNotContain(await c.ListAll(ct), x => (string?)x?["hash"] == Hash);
    }
}
