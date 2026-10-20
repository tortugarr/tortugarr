using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>
/// The plugin takes qBittorrent's address from Radarr's download clients, so moving the client
/// there (the container stopped for a qBittorrent on Windows, 2026-10-18) cannot leave the
/// plugin asking the old one.
/// </summary>
public class ArrQbitAddressTests
{
    private static JsonNode Client(string implementation, bool enable, int priority, string host, int port,
        bool useSsl = false, string urlBase = "") => new JsonObject
    {
        ["implementation"] = implementation,
        ["enable"] = enable,
        ["priority"] = priority,
        ["fields"] = new JsonArray(
            new JsonObject { ["name"] = "host", ["value"] = host },
            new JsonObject { ["name"] = "port", ["value"] = port },
            new JsonObject { ["name"] = "useSsl", ["value"] = useSsl },
            new JsonObject { ["name"] = "urlBase", ["value"] = urlBase },
            new JsonObject { ["name"] = "password", ["value"] = "********" }),
    };

    [Fact]
    public void Enabled_qbittorrent_is_used()
    {
        var clients = new JsonArray(Client("QBittorrent", true, 1, "192.168.1.15", 8070));
        Assert.Equal("http://192.168.1.15:8070", ArrQbitAddress.From(clients));
    }

    [Fact]
    public void Disabled_and_other_clients_are_skipped()
    {
        var clients = new JsonArray(
            Client("QBittorrent", false, 1, "qbittorrent", 8080),
            Client("Transmission", true, 1, "transmission", 9091),
            Client("QBittorrent", true, 2, "192.168.1.15", 8070));
        Assert.Equal("http://192.168.1.15:8070", ArrQbitAddress.From(clients));
    }

    [Fact]
    public void Best_priority_wins()
    {
        var clients = new JsonArray(
            Client("QBittorrent", true, 5, "backup", 8080),
            Client("QBittorrent", true, 1, "main", 8080));
        Assert.Equal("http://main:8080", ArrQbitAddress.From(clients));
    }

    [Fact]
    public void Ssl_and_url_base_are_kept()
    {
        var clients = new JsonArray(Client("QBittorrent", true, 1, "nas", 443, useSsl: true, urlBase: "/qbit/"));
        Assert.Equal("https://nas:443/qbit", ArrQbitAddress.From(clients));
    }

    [Fact]
    public void Nothing_usable_gives_null()
    {
        Assert.Null(ArrQbitAddress.From(null));
        Assert.Null(ArrQbitAddress.From(new JsonArray()));
        Assert.Null(ArrQbitAddress.From(new JsonArray(Client("QBittorrent", true, 1, "", 8080))));
    }
}
