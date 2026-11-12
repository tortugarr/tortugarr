using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

public class SeerrFourKSyncTests
{
    private static JsonObject M(int id, int status, int status4k) => new() { ["id"] = id, ["status"] = status, ["status4k"] = status4k };

    [Fact]
    public void A_title_in_the_library_gets_its_stuck_4K_status_set()
    {
        var stuck = SeerrFourKSync.Stuck4K(new JsonArray(M(1, 5, 3), M(2, 5, 2), M(3, 4, 3)));
        Assert.Equal(new[] { (1, "available"), (2, "available"), (3, "partial") }, stuck);
    }

    [Fact]
    public void Already_fine_deleted_blocklisted_or_not_in_the_library_is_left_alone()
    {
        var stuck = SeerrFourKSync.Stuck4K(new JsonArray(M(1, 5, 5), M(2, 5, 7), M(3, 5, 6), M(4, 3, 3), M(5, 5, 1)));
        Assert.Empty(stuck);
    }
}
