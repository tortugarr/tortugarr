using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

public class TopListDefaultsTests
{
    [Fact]
    public void A_server_on_the_first_four_lists_gets_the_new_ones()
    {
        var c = new PluginConfiguration { TopLists = TopListService.FirstDefaultLists };
        Assert.True(TopListService.AddNewDefaultLists(c));
        Assert.Equal(12, TopListService.Parse(c.TopLists).Count);
        Assert.Contains(TopListService.Parse(c.TopLists), l => l.Title == "Netflix Top 10 movies");
    }

    [Fact]
    public void Lists_the_user_changed_are_left_alone()
    {
        var c = new PluginConfiguration { TopLists = "Mine|someone/list" };
        Assert.False(TopListService.AddNewDefaultLists(c));
        Assert.Equal("Mine|someone/list", c.TopLists);
    }
}
