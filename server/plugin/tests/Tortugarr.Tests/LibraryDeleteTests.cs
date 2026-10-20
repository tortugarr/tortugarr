using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

public class LibraryDeleteTests
{
    [Theory]
    [InlineData("/data/media/movies/Sita (2008)/Sita.2008.1080p.mkv", "/data/media/movies/Sita (2008)/Sita.2008.1080p.mkv", true)]
    [InlineData("/movies/Sita (2008)/Sita.2008.1080p.mkv", "/data/media/movies/Sita (2008)/sita.2008.1080P.mkv", true)]
    [InlineData(@"C:\media\Sita.2008.1080p.mkv", "/data/media/movies/Sita.2008.1080p.mkv", true)]
    [InlineData("/data/media/movies/Sita (2008)/Sita.2008.720p.mkv", "/data/media/movies/Sita (2008)/Sita.2008.1080p.mkv", false)]
    [InlineData(null, "/data/media/movies/Sita.mkv", false)]
    [InlineData("/data/media/movies/Sita.mkv", null, false)]
    public void SameFile_compares_file_names_only(string? arr, string? jellyfin, bool same) =>
        Assert.Equal(same, LibraryDeleteService.SameFile(arr, jellyfin));

    [Fact]
    public void Sync_runs_two_minutes_after_the_last_removal()
    {
        var t0 = new DateTime(2026, 10, 6, 12, 0, 0, DateTimeKind.Utc);
        Assert.Equal(t0.AddMinutes(2), SeerrSync.DueAt(t0, t0));
        Assert.Equal(t0.AddMinutes(5), SeerrSync.DueAt(t0, t0.AddMinutes(3)));
    }

    [Fact]
    public void Sync_waits_at_most_ten_minutes_during_a_steady_stream() =>
        Assert.Equal(new DateTime(2026, 10, 6, 12, 10, 0, DateTimeKind.Utc),
            SeerrSync.DueAt(new DateTime(2026, 10, 6, 12, 0, 0, DateTimeKind.Utc), new DateTime(2026, 10, 6, 12, 9, 30, DateTimeKind.Utc)));
}

public class NoIndexersTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 6, 4, 45, 0, TimeSpan.Zero);

    private static System.Text.Json.Nodes.JsonArray A(string json) => System.Text.Json.Nodes.JsonNode.Parse(json)!.AsArray();

    [Fact]
    public void An_active_indexer_means_no_complaint() =>
        Assert.Null(TortugarrService.NoActiveIndexers("Radarr", A("[{\"id\":1,\"enableInteractiveSearch\":true}]"), A("[]"), false, Now));

    [Fact]
    public void No_indexers_at_all() =>
        Assert.Equal("Radarr has no indexers", TortugarrService.NoActiveIndexers("Radarr", A("[]"), A("[]"), false, Now));

    [Fact]
    public void Disabled_after_failures_names_the_time() =>
        Assert.Equal("Prowlarr has no active indexers: 1 disabled until 05:21 UTC after failures",
            TortugarrService.NoActiveIndexers("Prowlarr", A("[{\"id\":1,\"enable\":true}]"),
                A("[{\"indexerId\":1,\"disabledTill\":\"2026-10-06T05:21:15Z\"}]"), true, Now));

    [Fact]
    public void A_block_that_has_run_out_does_not_count() =>
        Assert.Null(TortugarrService.NoActiveIndexers("Prowlarr", A("[{\"id\":1,\"enable\":true}]"),
            A("[{\"indexerId\":1,\"disabledTill\":\"2026-10-06T04:00:00Z\"}]"), true, Now));

    [Fact]
    public void Interactive_search_switched_off() =>
        Assert.StartsWith("Sonarr has no active indexers: every indexer is switched off",
            TortugarrService.NoActiveIndexers("Sonarr", A("[{\"id\":2,\"enableInteractiveSearch\":false}]"), A("[]"), false, Now));
}

public class AlreadyInClientTests
{
    private static System.Text.Json.Nodes.JsonArray Q(string json) => System.Text.Json.Nodes.JsonNode.Parse(json)!.AsArray();

    private const string Torrents = "[{\"hash\":\"6b3be6b4\",\"name\":\"Sita.Sings.the.Blues.2008.1080p.WEB-DL.AAC2.0.H.264-TEST.mkv\",\"category\":\"radarr\",\"progress\":1}," +
        "{\"hash\":\"aaaa\",\"name\":\"Movie.2020.1080p.x264-GRP\",\"category\":\"radarr\",\"progress\":0.4}]";

    [Fact]
    public void Found_by_hash_first() =>
        Assert.Equal("aaaa", (string?)TortugarrService.FindTorrent(Q(Torrents), "AAAA", "something else")!["hash"]);

    [Fact]
    public void Found_by_name_without_the_video_extension() =>
        Assert.Equal("6b3be6b4", (string?)TortugarrService.FindTorrent(Q(Torrents), string.Empty, "Sita.Sings.the.Blues.2008.1080p.WEB-DL.AAC2.0.H.264-TEST")!["hash"]);

    [Fact]
    public void A_title_ending_in_a_codec_still_matches_its_folder() =>
        Assert.Equal("aaaa", (string?)TortugarrService.FindTorrent(Q(Torrents), string.Empty, "Movie.2020.1080p.x264-GRP")!["hash"]);

    [Fact]
    public void Another_release_is_not_a_match() =>
        Assert.Null(TortugarrService.FindTorrent(Q(Torrents), "ffff", "Sita.Sings.the.Blues.2008.720p.WEB-DL-OTHER"));
}

public class NoIndexersHealthTests
{
    [Fact]
    public void Health_error_counts_when_there_is_no_status_route() =>
        Assert.Equal("Radarr has no active indexers: All indexers are unavailable due to failures",
            TortugarrService.NoActiveIndexers("Radarr", System.Text.Json.Nodes.JsonNode.Parse("[{\"id\":1,\"enableInteractiveSearch\":true}]")!.AsArray(),
                new System.Text.Json.Nodes.JsonArray(), false, DateTimeOffset.UtcNow, "All indexers are unavailable due to failures"));
}

public class DeleteTorrentsTests
{
    private static System.Text.Json.Nodes.JsonArray H(string json) => System.Text.Json.Nodes.JsonNode.Parse(json)!.AsArray();

    [Fact]
    public void A_movie_takes_all_its_downloads() =>
        Assert.Equal(new[] { "AAA", "BBB" }, LibraryDeleteService.DownloadsFor(
            H("[{\"downloadId\":\"aaa\"},{\"downloadId\":\"AAA\"},{\"downloadId\":\"bbb\"},{\"downloadId\":null}]"), null));

    [Fact]
    public void An_episode_keeps_a_season_pack_other_episodes_came_from() =>
        Assert.Equal(new[] { "ONE" }, LibraryDeleteService.DownloadsFor(
            H("[{\"downloadId\":\"one\",\"episodeId\":1},{\"downloadId\":\"pack\",\"episodeId\":1},{\"downloadId\":\"pack\",\"episodeId\":2}]"), new[] { 1 }));
}

public class AllExceptAdultTests
{
    private static readonly Guid Movies = Guid.NewGuid(), Tv = Guid.NewGuid(), Adult = Guid.NewGuid();

    [Fact]
    public void Every_ordinary_library_means_all_except_adult() =>
        Assert.True(Jellyfin.Plugin.Tortugarr.Services.AdultLibraryService.AllExceptAdult(new[] { Movies, Tv }, new[] { Tv, Movies }));

    [Fact]
    public void A_list_narrowed_by_hand_is_left_alone() =>
        Assert.False(Jellyfin.Plugin.Tortugarr.Services.AdultLibraryService.AllExceptAdult(new[] { Movies, Tv }, new[] { Movies, Adult }));

    [Fact]
    public void No_known_libraries_means_no_match() =>
        Assert.False(Jellyfin.Plugin.Tortugarr.Services.AdultLibraryService.AllExceptAdult(Array.Empty<Guid>(), new[] { Movies }));
}

public class AdultDeleteTests
{
    [Theory]
    [InlineData("/data/media/adult/Clip.m4v", "/data/media/adult/Clip.m4v", true)]
    [InlineData("/data/media/adult/Pack/", "/data/media/adult/Pack/part1.mp4", true)]
    [InlineData("/data/media/adult/Pack", "/data/media/adult/Package/part1.mp4", false)]
    [InlineData("/data/media/adult/Other.m4v", "/data/media/adult/Clip.m4v", false)]
    [InlineData(null, "/data/media/adult/Clip.m4v", false)]
    public void A_download_owns_its_file_or_the_files_in_its_folder(string? contentPath, string file, bool owns) =>
        Assert.Equal(owns, LibraryDeleteService.OwnsFile(contentPath, file));
}

public class SpaceRuleTests
{
    private const long GB = 1024L * 1024 * 1024;

    [Fact]
    public void Enough_room_means_no_shortfall() =>
        Assert.Equal((12 * GB, 0L), SpaceService.Rule(2 * GB, 10 * GB, 0, 20 * GB));

    [Fact]
    public void Pending_downloads_count_against_the_free_space() =>
        Assert.Equal((12 * GB, 3 * GB), SpaceService.Rule(2 * GB, 10 * GB, 5 * GB, 14 * GB));
}

public class UnavailableIndexerTests
{
    [Fact]
    public void Names_come_from_the_arr_health_message() =>
        Assert.Equal(new[] { "Internet Archive", "1337x" },
            TortugarrService.NamesFromHealth("Indexers unavailable due to failures: Internet Archive (Prowlarr), 1337x (Prowlarr)"));

    [Fact]
    public void The_long_term_message_works_too() =>
        Assert.Equal(new[] { "Internet Archive" },
            TortugarrService.NamesFromHealth("Indexers unavailable due to failures for more than 6 hours: Internet Archive (Prowlarr)"));

    [Fact]
    public void No_message_no_names() => Assert.Empty(TortugarrService.NamesFromHealth(null));
}
