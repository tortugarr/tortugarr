using System.Text;
using Jellyfin.Plugin.Tortugarr.Services;
using MediaBrowser.Model.Updates;
using Xunit;

namespace Tortugarr.Tests;

public class MoonbaseGateTests
{
    // Stand-ins for DLLs: attribute strings sit between binary bytes.
    private static byte[] Dll(params string[] strings) =>
        strings.SelectMany(s => Encoding.UTF8.GetBytes(s).Prepend((byte)0x01).Append((byte)0x00)).ToArray();

    [Fact]
    public void A_version_that_drops_a_setting_the_app_syncs_is_held_back()
    {
        // Moonbase 2.4.0 had backdropEnabled, 2.5.0 renamed it homeBackdropEnabled.
        var v24 = Dll("Moonfin/Seerr", "Config", "backdropEnabled", "mediaBarEnabled");
        var v25 = Dll("Moonfin/Seerr", "Config", "homeBackdropEnabled", "mediaBarEnabled");
        Assert.Equal(new[] { "backdropEnabled" }, MoonbaseGate.Missing(v24, v25, new[] { "backdropEnabled", "mediaBarEnabled", "Moonfin/Seerr" }));
    }

    [Fact]
    public void An_entry_the_approved_version_never_had_does_not_count()
    {
        var approved = Dll("Moonfin/Settings");
        var candidate = Dll("Moonfin/Settings");
        Assert.Empty(MoonbaseGate.Missing(approved, candidate, new[] { "Moonfin/Settings", "seasonalFollower" }));
    }

    [Fact]
    public void A_route_counts_by_its_prefix()
    {
        var dll = Dll("Moonfin/Seerr/Api/{**path}");
        var tokens = MoonbaseGate.Tokens(dll);
        Assert.Contains("Moonfin/Seerr", tokens);
        Assert.Contains("Api", tokens);
    }

    [Fact]
    public void The_contract_is_embedded_and_holds_what_the_app_uses()
    {
        Assert.Contains("Moonfin/Seerr", MoonbaseGate.Contract);
        Assert.Contains("Moonfin/Settings", MoonbaseGate.Contract);
        Assert.Contains("backdropEnabled", MoonbaseGate.Contract);
        Assert.True(MoonbaseGate.Contract.Count > 300);
    }

    [Fact]
    public void The_moonfin_repository_is_switched_off_and_ours_on()
    {
        var repos = new List<RepositoryInfo>
        {
            new() { Name = "Jellyfin Stable", Url = "https://repo.jellyfin.org/files/plugin/manifest.json", Enabled = true },
            new() { Name = "Moonfin", Url = "https://raw.githubusercontent.com/Moonfin-Client/Plugin/master/manifest.json", Enabled = true },
            new() { Name = "Tortugarr", Url = "http://127.0.0.1:8096/Tortugarr/v1/Repository/manifest.json", Enabled = false },
        };
        Assert.True(MoonbaseGate.FixRepositories(repos));
        Assert.Equal(new[] { true, false, true }, repos.Select(r => r.Enabled));
        Assert.False(MoonbaseGate.FixRepositories(repos));
    }

    /// <summary>
    /// The real 2.4.0 and 3.0.0 DLLs (run with MOONBASE_DLL_DIR holding 2.4.0/ and 3.0.0/ from the
    /// Moonfin releases): the gate would have held 2.5.0/3.0.0 back for backdropEnabled alone.
    /// </summary>
    [Fact]
    public void Real_moonbase_3_0_lacks_only_backdropEnabled_compared_to_2_4()
    {
        var dir = Environment.GetEnvironmentVariable("MOONBASE_DLL_DIR");
        if (string.IsNullOrEmpty(dir) || !File.Exists(Path.Combine(dir, "2.4.0", "Moonfin.Server.dll")))
        {
            return; // Not available here.
        }

        var missing = MoonbaseGate.Missing(
            File.ReadAllBytes(Path.Combine(dir, "2.4.0", "Moonfin.Server.dll")),
            File.ReadAllBytes(Path.Combine(dir, "3.0.0", "Moonfin.Server.dll")),
            MoonbaseGate.Contract);
        Assert.Equal(new[] { "backdropEnabled" }, missing);
    }
}
