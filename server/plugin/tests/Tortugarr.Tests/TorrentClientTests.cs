using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-08: Transmission and Deluge behind the same face as qBittorrent.</summary>
public class TorrentClientTests
{
    [Theory]
    [InlineData(4, 0.4, 0, 1.0, "stalledDL")]
    [InlineData(4, 0.4, 2000, 1.0, "downloading")]
    [InlineData(4, 0.0, 0, 0.2, "metaDL")]
    [InlineData(0, 0.4, 0, 1.0, "stoppedDL")]
    [InlineData(0, 1.0, 0, 1.0, "stoppedUP")]
    [InlineData(2, 0.5, 0, 1.0, "checkingDL")]
    [InlineData(3, 0.5, 0, 1.0, "queuedDL")]
    [InlineData(6, 1.0, 0, 1.0, "uploading")]
    public void Transmission_states_become_qbittorrent_states(int status, double percent, long rate, double meta, string expected)
    {
        var t = JsonNode.Parse($$"""{"hashString":"ABC","name":"Film","status":{{status}},"percentDone":{{percent.ToString(System.Globalization.CultureInfo.InvariantCulture)}},"rateDownload":{{rate}},"metadataPercentComplete":{{meta.ToString(System.Globalization.CultureInfo.InvariantCulture)}},"leftUntilDone":500,"sizeWhenDone":1000}""")!;
        Assert.Equal(expected, (string?)TransmissionClient.Map(t)["state"]);
    }

    [Fact]
    public void Transmission_fields_map_to_qbittorrent_fields()
    {
        var t = JsonNode.Parse("""
            {"hashString":"ABCDEF","name":"Dune","status":4,"percentDone":0.25,"leftUntilDone":750,"sizeWhenDone":1000,"totalSize":1200,
             "doneDate":0,"addedDate":1700000000,"labels":["radarr"],"downloadDir":"/data/torrents/movies/","rateDownload":10,"peersSendingToUs":3,"error":0}
            """)!;
        var m = TransmissionClient.Map(t);
        Assert.Equal("abcdef", (string?)m["hash"]);
        Assert.Equal("radarr", (string?)m["category"]);
        Assert.Equal(750, (long?)m["amount_left"]);
        Assert.Equal(-1, (long?)m["completion_on"]);
        Assert.Equal("/data/torrents/movies/Dune", (string?)m["content_path"]);
        Assert.Equal(3, (int?)m["num_seeds"]);
    }

    [Fact]
    public void Transmission_without_labels_takes_the_folder_as_category()
    {
        var m = TransmissionClient.Map(JsonNode.Parse("""{"hashString":"a","name":"x","status":6,"percentDone":1,"downloadDir":"/downloads/tv-sonarr"}""")!);
        Assert.Equal("tv-sonarr", (string?)m["category"]);
    }

    [Theory]
    [InlineData("Downloading", 40, 1000, 400, 0, false, "stalledDL")]
    [InlineData("Downloading", 40, 1000, 400, 5000, false, "downloading")]
    [InlineData("Downloading", 0, 0, 0, 0, false, "metaDL")]
    [InlineData("Paused", 40, 1000, 400, 0, false, "stoppedDL")]
    [InlineData("Seeding", 100, 1000, 1000, 0, true, "uploading")]
    [InlineData("Queued", 10, 1000, 100, 0, false, "queuedDL")]
    [InlineData("Error", 10, 1000, 100, 0, false, "error")]
    public void Deluge_states_become_qbittorrent_states(string state, double progress, long wanted, long done, long rate, bool finished, string expected)
    {
        var t = new JsonObject
        {
            ["state"] = state, ["progress"] = progress, ["total_wanted"] = wanted, ["total_done"] = done,
            ["download_payload_rate"] = rate, ["is_finished"] = finished, ["name"] = "Show", ["label"] = "sonarr", ["save_path"] = "/downloads",
        };
        var m = DelugeClient.Map("HASH", t);
        Assert.Equal(expected, (string?)m["state"]);
        Assert.Equal("hash", (string?)m["hash"]);
        Assert.Equal("sonarr", (string?)m["category"]);
        Assert.Equal(progress / 100.0, (double?)m["progress"]);
    }

    [Fact]
    public void Deluge_amount_left_and_magnet_without_metadata()
    {
        var withData = DelugeClient.Map("h", new JsonObject { ["state"] = "Downloading", ["progress"] = 40.0, ["total_wanted"] = 1000, ["total_done"] = 400 });
        Assert.Equal(600, (long?)withData["amount_left"]);
        var magnet = DelugeClient.Map("h", new JsonObject { ["state"] = "Downloading", ["progress"] = 0.0, ["total_wanted"] = 0, ["total_done"] = 0 });
        Assert.Equal(-1, (long?)magnet["amount_left"]);
    }

    private sealed class Handler : HttpMessageHandler
    {
        public readonly List<(string? Session, string Body)> Seen = new();

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var session = request.Headers.TryGetValues("X-Transmission-Session-Id", out var v) ? v.FirstOrDefault() : null;
            Seen.Add((session, await request.Content!.ReadAsStringAsync(cancellationToken)));
            if (session != "s-1")
            {
                var conflict = new HttpResponseMessage(HttpStatusCode.Conflict);
                conflict.Headers.Add("X-Transmission-Session-Id", "s-1");
                return conflict;
            }

            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("""{"result":"success","arguments":{"version":"4.1.0","torrents":[{"hashString":"AA","name":"n","status":6,"percentDone":1}]}}""", Encoding.UTF8, "application/json"),
            };
        }
    }

    [Fact]
    public async Task Transmission_does_the_session_handshake_and_lists()
    {
        var h = new Handler();
        var c = new TransmissionClient(new HttpClient(h), "http://transmission:9091", "", "");
        Assert.Equal("4.1.0", await c.Version(CancellationToken.None));
        Assert.Equal(2, h.Seen.Count); // 409 first, then with the session id
        var list = await c.ListAll(CancellationToken.None);
        Assert.Equal("uploading", (string?)list[0]!["state"]);
        Assert.Equal(3, h.Seen.Count); // the session id is kept
        Assert.Contains("\"torrent-get\"", h.Seen[2].Body);
    }

    [Fact]
    public void The_factory_picks_the_client_and_refuses_none()
    {
        var http = new HttpClient();
        Assert.Equal("qBittorrent", TorrentClient.Create(http, "qbittorrent", "http://q:8080", "", "").Name);
        Assert.Equal("Transmission", TorrentClient.Create(http, "transmission", "http://t:9091", "", "").Name);
        Assert.Equal("Deluge", TorrentClient.Create(http, "deluge", "http://d:8112", "", "").Name);
        Assert.Throws<NotConfiguredException>(() => TorrentClient.Create(http, "none", "", "", ""));
    }
}
