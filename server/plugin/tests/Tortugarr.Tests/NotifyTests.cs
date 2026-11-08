using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-08: phone notifications through ntfy (G).</summary>
public class NotifyTests
{
    [Fact]
    public void Topics_are_secret_and_different()
    {
        var a = NotifyService.NewTopic();
        var b = NotifyService.NewTopic();
        Assert.Matches("^tortugarr-[a-z2-7]{26}$", a);
        Assert.NotEqual(a, b);
    }

    [Fact]
    public void The_app_link_opens_ntfy_with_the_subscription()
    {
        Assert.Equal("ntfy://192.168.1.15:8099/tortugarr-abc?secure=false", NotifyService.AppLink("http://192.168.1.15:8099", "tortugarr-abc"));
        Assert.Equal("ntfy://push.example.org/t", NotifyService.AppLink("https://push.example.org", "t"));
    }

    [Fact]
    public void Ready_goes_to_the_owner_and_admins_who_want_everything_only()
    {
        var owner = Guid.NewGuid();
        var users = new[]
        {
            new NotifyUser { UserId = owner.ToString("N"), Topic = "t-owner", Ready = true },
            new NotifyUser { UserId = Guid.NewGuid().ToString("N"), Topic = "t-other", Ready = true },
            new NotifyUser { UserId = Guid.NewGuid().ToString("N"), Topic = "t-admin", Ready = true, Everything = true },
            new NotifyUser { UserId = Guid.NewGuid().ToString("N"), Topic = "t-muted", Ready = false, Everything = true },
        };
        Assert.Equal(new[] { "t-owner", "t-admin" }, NotifyService.ReadyTopics(users, new[] { owner }));
        Assert.Equal(new[] { "t-admin" }, NotifyService.ReadyTopics(users, Array.Empty<Guid>()));
    }

    [Fact]
    public void Episodes_of_a_season_become_one_message()
    {
        Assert.Equal(("Ready: Fargo S02E03", "Fargo season 2 episode 3 is ready to watch."), NotifyService.EpisodeMessage("Fargo", 2, new[] { 3 }));
        var (title, text) = NotifyService.EpisodeMessage("Fargo", 2, new[] { 5, 3, 4 });
        Assert.Equal("Ready: Fargo S02 (3 episodes)", title);
        Assert.Equal("Fargo season 2: episodes 3, 4, 5 are ready to watch.", text);
    }

    [Fact]
    public void Non_ascii_titles_are_encoded_for_the_header()
    {
        Assert.Equal("Ready: Dune", NotifyService.HeaderSafe("Ready: Dune"));
        Assert.Equal("=?UTF-8?B?" + Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("Klar: Blåmann")) + "?=", NotifyService.HeaderSafe("Klar: Blåmann"));
    }
}
