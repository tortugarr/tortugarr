using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Jellyfin.Plugin.Tortugarr.Tests;

public class QbitKeepInPlaceTests
{
    [Fact]
    public void Category_change_never_relocates_torrents()
    {
        var pref = JsonNode.Parse(QbitClient.KeepTorrentsInPlace)!;
        Assert.False((bool)pref["category_changed_tmm_enabled"]!);
    }
}
