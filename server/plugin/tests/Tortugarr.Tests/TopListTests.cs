using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-08: top lists from public MDBList lists as home rows.</summary>
public class TopListTests
{
    [Fact]
    public void The_default_lists_parse()
    {
        var lists = TopListService.Parse(new PluginConfiguration().TopLists);
        Assert.Equal(4, lists.Count);
        Assert.Equal(new TopListDef(0, "Most watched films this week", "linaspurinis/top-watched-movies-of-the-week"), lists[0]);
        Assert.Equal("IMDb Top 250", lists[3].Title);
    }

    [Fact]
    public void Comments_blank_lines_and_bad_lines_are_skipped()
    {
        var lists = TopListService.Parse("# mine\n\nTop|a/b\nno list here\nBad|https://evil/x\n|a/c\nMore|user.x/list-2\r\n");
        Assert.Equal(new[] { "Top", "More" }, lists.Select(l => l.Title));
        Assert.Equal(new[] { 0, 1 }, lists.Select(l => l.Index));
    }

    [Fact]
    public void Entries_keep_order_map_shows_to_tv_and_drop_adult_and_idless()
    {
        var list = JsonNode.Parse("""
            [
              {"id": 247718, "rank": 1, "adult": 0, "title": "MobLand", "tvdbid": 446831, "imdb_id": "tt31510819", "mediatype": "show", "release_year": 2025},
              {"id": 0, "title": "No id", "mediatype": "movie"},
              {"id": 5, "adult": 1, "title": "Adult", "mediatype": "movie"},
              {"id": 278, "adult": 0, "title": "The Shawshank Redemption", "tvdbid": null, "imdb_id": "tt0111161", "mediatype": "movie", "release_year": 1994}
            ]
            """) as JsonArray;
        var e = TopListService.Entries(list!);
        Assert.Equal(2, e.Count);
        Assert.Equal(new TopEntry(247718, 446831, "tt31510819", "tv", "MobLand", 2025), e[0]);
        Assert.Equal(("movie", 278, (int?)null), (e[1].MediaType, e[1].TmdbId, e[1].TvdbId));
    }
}

/// <summary>2026-11-08: two films with the same title and year.</summary>
public class FolderCollisionTests
{
    [Fact]
    public void A_taken_folder_is_recognised_and_gets_the_id_tag()
    {
        var radarr = new UpstreamException("Radarr", "HTTP 400 [{\"propertyName\":\"Path\",\"errorMessage\":\"Path '/data/library/7/The Odyssey (2026)' is already configured for an existing movie\",\"errorCode\":\"MoviePathValidator\"}]");
        Assert.True(TortugarrService.IsFolderTaken(radarr));
        Assert.False(TortugarrService.IsFolderTaken(new UpstreamException("Radarr", "HTTP 500")));
        Assert.False(TortugarrService.IsFolderTaken(new InvalidOperationException("is already configured for an existing movie")));
        Assert.Equal("/data/library/7/The Odyssey (2026) [tmdbid-1698863]", TortugarrService.TaggedFolder("/data/library/7/", "The Odyssey (2026)", "tmdbid-1698863"));
    }
}

public class FolderNameTests
{
    [Fact]
    public void Folder_name_falls_back_to_title_and_year_without_bad_characters()
    {
        Assert.Equal("The Odyssey (2026)", TortugarrService.FolderName(new System.Text.Json.Nodes.JsonObject { ["title"] = "The Odyssey", ["year"] = 2026 }));
        Assert.Equal("Mission Impossible (1996)", TortugarrService.FolderName(new System.Text.Json.Nodes.JsonObject { ["title"] = "Mission: Impossible", ["year"] = 1996 }).Replace("  ", " "));
        Assert.Equal("Given (2020)", TortugarrService.FolderName(new System.Text.Json.Nodes.JsonObject { ["folder"] = "Given (2020)", ["title"] = "x" }));
    }
}
