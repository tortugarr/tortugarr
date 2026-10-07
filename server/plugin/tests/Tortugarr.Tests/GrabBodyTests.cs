using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>
/// The grab sends the title's id along, so Radarr/Sonarr can grab a release they could not match
/// themselves (an SD release of "Sita Sings the Blues" came back as 404 "Unable to find matching
/// movie", shown to the user as "search expired" - Windows rehearsal, 2026-10-07).
/// </summary>
public class GrabBodyTests
{
    [Fact]
    public void Movie_sends_movieId()
    {
        var b = TortugarrService.GrabBody("movie", 42, "g1", 7);
        Assert.Equal("g1", b["guid"]);
        Assert.Equal(7, b["indexerId"]);
        Assert.Equal(42, b["movieId"]);
        Assert.False(b.ContainsKey("seriesId"));
    }

    [Fact]
    public void Episode_sends_episodeId()
    {
        var b = TortugarrService.GrabBody("episode", 1001, "g2", 3);
        Assert.Equal(1001, b["episodeId"]);
        Assert.False(b.ContainsKey("movieId"));
    }

    [Fact]
    public void Season_sends_seriesId()
    {
        var b = TortugarrService.GrabBody("season", 55, "g3", 3);
        Assert.Equal(55, b["seriesId"]);
        Assert.False(b.ContainsKey("episodeId"));
    }
}
