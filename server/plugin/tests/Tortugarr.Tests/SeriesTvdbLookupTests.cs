using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

public class SeriesTvdbLookupTests
{
    // Sonarr's answer to term=tmdb:300755 on 2026-11-05: the right series, then a series whose
    // TVDB id happens to be 300755.
    private static JsonArray Lookup() => JsonNode.Parse("""
        [{"title":"The Traitor Within","tvdbId":469502,"tmdbId":300755},
         {"title":"Jokers Wild","tvdbId":300755,"tmdbId":11590}]
        """)!.AsArray();

    [Fact]
    public void Takes_the_series_whose_tmdb_id_matches() =>
        Assert.Equal(469502, SeriesService.PickTvdbForTmdb(Lookup(), 300755));

    [Fact]
    public void A_number_that_only_matches_a_tvdb_id_gives_nothing() =>
        Assert.Null(SeriesService.PickTvdbForTmdb(Lookup(), 999));

    [Fact]
    public void No_answer_gives_nothing() =>
        Assert.Null(SeriesService.PickTvdbForTmdb(null, 300755));
}
