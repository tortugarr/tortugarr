using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

// 2026-10-21: 1337x only works through FlareSolverr, and users did not know to tag it.
public class FlareSolverrTaggerTests
{
    private static JsonArray A(string json) => JsonNode.Parse(json)!.AsArray();

    [Fact]
    public void ProxyTagIsTheFlareSolverrProxysTag()
    {
        Assert.Equal(3, FlareSolverrTagger.ProxyTag(A("[{\"implementation\":\"Http\",\"tags\":[9]},{\"implementation\":\"FlareSolverr\",\"tags\":[3]}]")));
        Assert.Null(FlareSolverrTagger.ProxyTag(A("[{\"implementation\":\"FlareSolverr\",\"tags\":[]}]")));
        Assert.Null(FlareSolverrTagger.ProxyTag(A("[]")));
    }

    [Fact]
    public void OnlyIndexersWithoutTheTagAreReturned()
    {
        var untagged = FlareSolverrTagger.Untagged(A("[{\"id\":1,\"name\":\"1337x\",\"tags\":[]},{\"id\":2,\"tags\":[3]},{\"id\":3,\"tags\":[5]},{\"id\":4}]"), 3);
        Assert.Equal(new[] { 1, 3, 4 }, untagged.Select(i => (int)i["id"]!));
    }
}
