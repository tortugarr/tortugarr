using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>
/// A new download shows before Radarr/Sonarr have it in their queue (they read the client once
/// a minute; 2026-10-21 Clean Hands had no bar for its first minute).
/// </summary>
public class EarlyGrabTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-10-21T07:34:00Z");

    private static JsonArray History(params (string Event, string Id, string Date)[] rows) =>
        new(rows.Select(r => (JsonNode)new JsonObject
        {
            ["eventType"] = r.Event, ["downloadId"] = r.Id, ["date"] = r.Date,
        }).ToArray());

    private static List<string?> Ids(List<JsonNode> grabs) => grabs.Select(g => (string?)g["downloadId"]).ToList();

    [Fact]
    public void A_fresh_grab_not_in_the_queue_shows()
    {
        var h = History(("grabbed", "ABC", "2026-10-21T07:33:03Z"));
        Assert.Equal(new[] { "ABC" }, Ids(TortugarrService.EarlyGrabs(h, new HashSet<string>(), Now)));
    }

    [Fact]
    public void Queued_imported_failed_or_old_grabs_do_not()
    {
        var h = History(
            ("downloadFolderImported", "DONE", "2026-10-21T07:30:00Z"),
            ("grabbed", "DONE", "2026-10-21T07:29:00Z"),
            ("downloadFailed", "BAD", "2026-10-21T07:31:00Z"),
            ("grabbed", "BAD", "2026-10-21T07:30:30Z"),
            ("grabbed", "Q", "2026-10-21T07:32:00Z"),
            ("grabbed", "OLD", "2026-10-21T07:00:00Z"));
        var queued = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "q" };
        Assert.Empty(TortugarrService.EarlyGrabs(h, queued, Now));
    }

    [Fact]
    public void A_season_pack_counts_once()
    {
        var h = History(("grabbed", "PACK", "2026-10-21T07:33:00Z"), ("grabbed", "PACK", "2026-10-21T07:33:00Z"));
        Assert.Single(TortugarrService.EarlyGrabs(h, new HashSet<string>(), Now));
    }
}
