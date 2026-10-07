using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

public class ArrHookTests
{
    [Fact]
    public void Radarr_import_gives_the_file_then_the_folder() =>
        Assert.Equal(new[] { "/data/media/movies/Sita (2008)/Sita.mkv", "/data/media/movies/Sita (2008)" },
            ArrHookService.HookPaths(JsonNode.Parse("""
                {"eventType":"Download","movie":{"folderPath":"/data/media/movies/Sita (2008)"},
                 "movieFile":{"relativePath":"Sita.mkv","path":"/data/media/movies/Sita (2008)/Sita.mkv"}}
                """)!));

    [Fact]
    public void Sonarr_episode_delete_gives_the_deleted_file_and_the_series() =>
        Assert.Equal(new[] { "/data/media/tv/Pioneer One/Season 1/E01.mkv", "/data/media/tv/Pioneer One" },
            ArrHookService.HookPaths(JsonNode.Parse("""
                {"eventType":"EpisodeFileDelete","series":{"path":"/data/media/tv/Pioneer One"},
                 "episodeFile":{"path":"/data/media/tv/Pioneer One/Season 1/E01.mkv"}}
                """)!));

    [Fact]
    public void Relative_or_missing_paths_are_ignored() =>
        Assert.Empty(ArrHookService.HookPaths(JsonNode.Parse("""{"eventType":"Test","movieFile":{"path":"relative.mkv"}}""")!));
}

public class HookKeyTests
{
    [Theory]
    [InlineData("abc123", "abc123", true)]
    [InlineData("abc123", "abc124", false)]
    [InlineData("abc123", "", false)]
    [InlineData("abc123", null, false)]
    [InlineData("", "", false)]
    [InlineData(null, "anything", false)]
    public void Only_the_configured_key_opens_the_hook(string? configured, string? sent, bool ok) =>
        Assert.Equal(ok, Jellyfin.Plugin.Tortugarr.Api.TortugarrController.HookKeyOk(configured, sent));
}
