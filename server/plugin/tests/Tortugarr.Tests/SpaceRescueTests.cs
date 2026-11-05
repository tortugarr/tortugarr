using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

public class SpaceRescueTests
{
    [Fact]
    public void The_Detective_Hole_import_held_for_space_is_found()
    {
        // Sonarr's queue on 2026-11-05 (trimmed).
        var queue = (JsonArray)JsonNode.Parse("""
            [
              {"seriesId": 8, "title": "Jo Nesbos Detective Hole S01E04 1080p", "trackedDownloadState": "importBlocked",
               "statusMessages": [{"title": "Jo Nesbos Detective Hole S01E04 1080p",
                 "messages": ["Not enough free space (100.00 MB) to import after download: 67.2 MB. (Settings: Media Management: Minimum Free Space)"]}]},
              {"seriesId": 3, "title": "Stick S01E07", "trackedDownloadState": "downloading", "statusMessages": []},
              {"seriesId": 5, "title": "Other", "statusMessages": [{"title": "x", "messages": ["No files found are eligible for import"]}]}
            ]
            """)!;
        Assert.Equal(new[] { 8 }, SpaceRescue.HeldForSpace(queue, "seriesId"));
    }

    [Fact]
    public void A_movie_queue_uses_the_movie_id()
    {
        var queue = (JsonArray)JsonNode.Parse("""
            [{"movieId": 42, "statusMessages": [{"title": "Not enough free space", "messages": []}]}]
            """)!;
        Assert.Equal(new[] { 42 }, SpaceRescue.HeldForSpace(queue, "movieId"));
    }

    [Fact]
    public void Seerr_default_folder_moves_to_the_roomiest_root_and_anime_follows()
    {
        var server = (JsonObject)JsonNode.Parse("""
            {"id": 0, "name": "Sonarr", "activeDirectory": "/data/library/4", "activeAnimeDirectory": "/data/library/4", "apiKey": "k"}
            """)!;
        var changed = SpaceRescue.WithFolder(server, "/data/library/9")!;
        Assert.Equal("/data/library/9", (string?)changed["activeDirectory"]);
        Assert.Equal("/data/library/9", (string?)changed["activeAnimeDirectory"]);
        Assert.Equal("k", (string?)changed["apiKey"]); // the rest is sent back unchanged
        Assert.Equal("/data/library/4", (string?)server["activeDirectory"]); // the input is not touched
    }

    [Fact]
    public void Seerr_is_left_alone_when_it_already_uses_the_roomiest_root()
    {
        var server = (JsonObject)JsonNode.Parse("""{"id": 0, "activeDirectory": "/data/library/9/"}""")!;
        Assert.Null(SpaceRescue.WithFolder(server, "/data/library/9"));
    }

    [Fact]
    public void A_separate_anime_folder_is_kept()
    {
        var server = (JsonObject)JsonNode.Parse("""{"id": 0, "activeDirectory": "/data/library/4", "activeAnimeDirectory": "/data/anime"}""")!;
        Assert.Equal("/data/anime", (string?)SpaceRescue.WithFolder(server, "/data/library/9")!["activeAnimeDirectory"]);
    }
}
