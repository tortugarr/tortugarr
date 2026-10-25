using System.Text.Json;
using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>The settings page (2026-10-25): keys are write-only, a bad field changes nothing.</summary>
public class SettingsTests
{
    private static PluginConfiguration Saved() => new()
    {
        SonarrUrl = "http://sonarr:8989",
        SonarrApiKey = "secret-sonarr-key",
        DownloadClientPassword = "secret-password",
        HookKey = "secret-hook",
        ManagedUserIds = new[] { "u1" },
    };

    [Fact]
    public void View_never_carries_a_key_a_password_or_internal_state()
    {
        var json = JsonSerializer.Serialize(SettingsService.View(Saved()));
        Assert.DoesNotContain("secret", json, StringComparison.Ordinal);
        Assert.DoesNotContain("HookKey", json, StringComparison.Ordinal);
        Assert.DoesNotContain("ManagedUserIds", json, StringComparison.Ordinal);
        Assert.DoesNotContain("UserLimits", json, StringComparison.Ordinal);
        var view = SettingsService.View(Saved());
        Assert.Equal(true, view["SonarrApiKeySet"]);
        Assert.Equal(false, view["RadarrApiKeySet"]);
        Assert.Equal("http://sonarr:8989", view["SonarrUrl"]);
    }

    [Fact]
    public void An_empty_key_keeps_the_saved_one_and_a_new_one_replaces_it()
    {
        var c = Saved();
        SettingsService.Apply(c, JsonNode.Parse("""{"SonarrApiKey":"","DownloadClientPassword":"new-pass"}""")!.AsObject());
        Assert.Equal("secret-sonarr-key", c.SonarrApiKey);
        Assert.Equal("new-pass", c.DownloadClientPassword);
    }

    [Fact]
    public void Numbers_switches_and_addresses_are_read_from_the_page()
    {
        var c = Saved();
        SettingsService.Apply(c, JsonNode.Parse("""
            {"SpaceBufferBytes":"5368709120","SearchTimeoutSeconds":"90","AdultEnabled":true,
             "RadarrUrl":"http://radarr:7878/","DownloadClientType":"qbittorrent"}
            """)!.AsObject());
        Assert.Equal(5L * 1024 * 1024 * 1024, c.SpaceBufferBytes);
        Assert.Equal(90, c.SearchTimeoutSeconds);
        Assert.True(c.AdultEnabled);
        Assert.Equal("http://radarr:7878", c.RadarrUrl);
        Assert.Equal("qbittorrent", c.DownloadClientType);
    }

    [Theory]
    [InlineData("""{"SonarrUrl":"sonarr:8989"}""", "SonarrUrl")]
    [InlineData("""{"JunkRegex":"(cam"}""", "JunkRegex")]
    [InlineData("""{"MinMovieBytes":"-1"}""", "MinMovieBytes")]
    [InlineData("""{"DownloadClientType":"utorrent"}""", "DownloadClientType")]
    public void A_wrong_field_is_named_and_nothing_is_saved(string body, string field)
    {
        var c = Saved();
        var all = JsonNode.Parse(body)!.AsObject();
        all["TvCategory"] = "changed";
        var e = Assert.Throws<ArgumentException>(() => SettingsService.Apply(c, all));
        Assert.StartsWith(field, e.Message, StringComparison.Ordinal);
        Assert.Equal("sonarr", c.TvCategory);
        Assert.Equal("http://sonarr:8989", c.SonarrUrl);
    }

    [Fact]
    public void Internal_state_can_not_be_written_from_the_page()
    {
        var c = Saved();
        SettingsService.Apply(c, JsonNode.Parse("""{"HookKey":"x","ManagedUserIds":["evil"],"UserLimits":[]}""")!.AsObject());
        Assert.Equal("secret-hook", c.HookKey);
        Assert.Equal(new[] { "u1" }, c.ManagedUserIds);
    }

    [Fact]
    public void Every_listed_field_exists_in_the_configuration()
    {
        foreach (var name in SettingsService.Fields.Keys)
        {
            Assert.NotNull(typeof(PluginConfiguration).GetProperty(name));
        }
    }
}
