using System.Globalization;
using System.Reflection;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Jellyfin.Plugin.Tortugarr.Configuration;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// The plugin's settings page (Dashboard › Plugins › Tortugarr, user 2026-10-25): which settings an
/// administrator may see and change, and a connection test per service. Keys and passwords are
/// write-only: the page only learns whether one is set, and an empty field keeps the saved one.
/// Internal state (hook key, known libraries, users hidden from the adult library) is never shown.
/// </summary>
public sealed class SettingsService
{
    internal enum Kind
    {
        Text,
        Url,
        Secret,
        Regex,
        Number,
        Switch,
    }

    /// <summary>Every setting the page shows, in no particular order (the page groups them).</summary>
    internal static readonly IReadOnlyDictionary<string, Kind> Fields = new Dictionary<string, Kind>
    {
        [nameof(PluginConfiguration.SonarrUrl)] = Kind.Url,
        [nameof(PluginConfiguration.SonarrApiKey)] = Kind.Secret,
        [nameof(PluginConfiguration.RadarrUrl)] = Kind.Url,
        [nameof(PluginConfiguration.RadarrApiKey)] = Kind.Secret,
        [nameof(PluginConfiguration.ProwlarrUrl)] = Kind.Url,
        [nameof(PluginConfiguration.ProwlarrApiKey)] = Kind.Secret,
        [nameof(PluginConfiguration.BazarrUrl)] = Kind.Url,
        [nameof(PluginConfiguration.BazarrApiKey)] = Kind.Secret,
        [nameof(PluginConfiguration.SeerrUrl)] = Kind.Url,
        [nameof(PluginConfiguration.SeerrApiKey)] = Kind.Secret,
        [nameof(PluginConfiguration.DownloadClientType)] = Kind.Text,
        [nameof(PluginConfiguration.DownloadClientUrl)] = Kind.Url,
        [nameof(PluginConfiguration.DownloadClientUsername)] = Kind.Text,
        [nameof(PluginConfiguration.DownloadClientPassword)] = Kind.Secret,
        [nameof(PluginConfiguration.MovieCategory)] = Kind.Text,
        [nameof(PluginConfiguration.TvCategory)] = Kind.Text,
        [nameof(PluginConfiguration.DownloadRoots)] = Kind.Text,
        [nameof(PluginConfiguration.MovieRoots)] = Kind.Text,
        [nameof(PluginConfiguration.DocumentaryRoots)] = Kind.Text,
        [nameof(PluginConfiguration.TvRoots)] = Kind.Text,
        [nameof(PluginConfiguration.SpaceBufferBytes)] = Kind.Number,
        [nameof(PluginConfiguration.SearchTimeoutSeconds)] = Kind.Number,
        [nameof(PluginConfiguration.AdultEnabled)] = Kind.Switch,
        [nameof(PluginConfiguration.AdultCategory)] = Kind.Text,
        [nameof(PluginConfiguration.AdultSavePath)] = Kind.Text,
        [nameof(PluginConfiguration.AdultDownloadPath)] = Kind.Text,
        [nameof(PluginConfiguration.AdultLibraryName)] = Kind.Text,
        [nameof(PluginConfiguration.AdultCategories)] = Kind.Text,
        [nameof(PluginConfiguration.AdultMinBytes)] = Kind.Number,
        [nameof(PluginConfiguration.AdultUnsafeRegex)] = Kind.Regex,
        [nameof(PluginConfiguration.JunkRegex)] = Kind.Regex,
        [nameof(PluginConfiguration.QualityRegex)] = Kind.Regex,
        [nameof(PluginConfiguration.HardRejectionRegex)] = Kind.Regex,
        [nameof(PluginConfiguration.MinEpisodeBytes)] = Kind.Number,
        [nameof(PluginConfiguration.MinMovieBytes)] = Kind.Number,
        [nameof(PluginConfiguration.MinSdEpisodeBytes)] = Kind.Number,
        [nameof(PluginConfiguration.MinSdMovieBytes)] = Kind.Number,
        [nameof(PluginConfiguration.MinVideoBytes)] = Kind.Number,
        [nameof(PluginConfiguration.EarlyReleaseDays)] = Kind.Number,
        [nameof(PluginConfiguration.BannedExtensions)] = Kind.Text,
        [nameof(PluginConfiguration.VideoExtensions)] = Kind.Text,
    };

    internal static readonly string[] DownloadClientTypes = { "qbittorrent", "transmission", "deluge", "none" };

    private readonly IHttpClientFactory _httpFactory;

    public SettingsService(IHttpClientFactory httpFactory)
    {
        _httpFactory = httpFactory;
    }

    /// <summary>What the page gets: every field, with a secret only as "<c>Name</c>Set": true/false.</summary>
    internal static Dictionary<string, object?> View(PluginConfiguration c)
    {
        var view = new Dictionary<string, object?>();
        foreach (var (name, kind) in Fields)
        {
            var value = Prop(name).GetValue(c);
            if (kind == Kind.Secret)
            {
                view[name + "Set"] = !string.IsNullOrEmpty(value as string);
            }
            else
            {
                view[name] = value;
            }
        }

        return view;
    }

    /// <summary>
    /// Saves what the page sent. Everything is checked first and nothing changes when one field is
    /// wrong (ArgumentException names it). A secret changes only when a new value is sent; an empty
    /// one keeps the saved value. Fields the page did not send stay as they are.
    /// </summary>
    internal static void Apply(PluginConfiguration c, JsonObject body)
    {
        var changes = new List<(PropertyInfo Prop, object? Value)>();
        foreach (var (name, node) in body)
        {
            if (!Fields.TryGetValue(name, out var kind))
            {
                continue; // read-only or unknown: ignored, never an error the user can not fix
            }

            var prop = Prop(name);
            var text = node is JsonValue v && v.TryGetValue<string>(out var s) ? s : node?.ToJsonString();
            switch (kind)
            {
                case Kind.Secret:
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        changes.Add((prop, text.Trim()));
                    }

                    break;
                case Kind.Switch:
                    changes.Add((prop, node is JsonValue b && b.TryGetValue<bool>(out var on) ? on
                        : string.Equals(text, "true", StringComparison.OrdinalIgnoreCase)));
                    break;
                case Kind.Number:
                    if (!long.TryParse(text?.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) || n < 0)
                    {
                        throw new ArgumentException($"{name}: a whole number, 0 or more");
                    }

                    changes.Add((prop, prop.PropertyType == typeof(int) ? (object)(int)Math.Min(n, int.MaxValue) : n));
                    break;
                case Kind.Url:
                    var url = (text ?? string.Empty).Trim();
                    if (url.Length > 0 && !(Uri.TryCreate(url, UriKind.Absolute, out var u) && (u.Scheme == "http" || u.Scheme == "https")))
                    {
                        throw new ArgumentException($"{name}: an address like http://sonarr:8989");
                    }

                    changes.Add((prop, url.TrimEnd('/')));
                    break;
                case Kind.Regex:
                    try
                    {
                        _ = new Regex(text ?? string.Empty, RegexOptions.None, TimeSpan.FromSeconds(1));
                    }
                    catch (ArgumentException e)
                    {
                        throw new ArgumentException($"{name}: not a valid pattern ({e.Message})");
                    }

                    changes.Add((prop, text ?? string.Empty));
                    break;
                default:
                    if (name == nameof(PluginConfiguration.DownloadClientType) && !DownloadClientTypes.Contains(text))
                    {
                        throw new ArgumentException($"{name}: one of {string.Join(", ", DownloadClientTypes)}");
                    }

                    changes.Add((prop, text ?? string.Empty));
                    break;
            }
        }

        foreach (var (prop, value) in changes)
        {
            prop.SetValue(c, value);
        }
    }

    private static PropertyInfo Prop(string name) =>
        typeof(PluginConfiguration).GetProperty(name) ?? throw new InvalidOperationException(name);

    /// <summary>A connection test request; an empty key or password means the saved one.</summary>
    public sealed class TestRequest
    {
        public string Service { get; set; } = string.Empty;

        public string Url { get; set; } = string.Empty;

        public string Key { get; set; } = string.Empty;

        public string Username { get; set; } = string.Empty;
    }

    /// <summary>Asks the service who it is. Answers ok plus its version, or the error as it came.</summary>
    public async Task<object> TestAsync(PluginConfiguration c, TestRequest t, CancellationToken ct)
    {
        string Saved(string field) => Prop(field).GetValue(c) as string ?? string.Empty;
        string Key(string field) => string.IsNullOrWhiteSpace(t.Key) ? Saved(field) : t.Key.Trim();
        var http = _httpFactory.CreateClient("tortugarr");
        http.Timeout = Timeout.InfiniteTimeSpan;
        try
        {
            var version = t.Service switch
            {
                "sonarr" => (string?)(await new ArrClient(http, "Sonarr", t.Url, Key("SonarrApiKey")).Get("/system/status", ct, 15).ConfigureAwait(false))?["version"],
                "radarr" => (string?)(await new ArrClient(http, "Radarr", t.Url, Key("RadarrApiKey")).Get("/system/status", ct, 15).ConfigureAwait(false))?["version"],
                "prowlarr" => (string?)(await new ArrClient(http, "Prowlarr", t.Url, Key("ProwlarrApiKey"), "/api/v1").Get("/system/status", ct, 15).ConfigureAwait(false))?["version"],
                "seerr" => (string?)(await new ArrClient(http, "Seerr", t.Url, Key("SeerrApiKey"), "/api/v1").Get("/settings/about", ct, 15).ConfigureAwait(false))?["version"],
                "bazarr" => (string?)(await new BazarrClient(http, t.Url, Key("BazarrApiKey")).Get("/system/status", ct, 15).ConfigureAwait(false))?["data"]?["bazarr_version"],
                "qbittorrent" => await QbitVersion(http, t, Key("DownloadClientPassword"), ct).ConfigureAwait(false),
                _ => throw new ArgumentException("service: sonarr, radarr, prowlarr, bazarr, seerr or qbittorrent"),
            };
            return new { ok = true, version = version ?? string.Empty };
        }
        catch (Exception e) when (e is UpstreamException or NotConfiguredException or HttpRequestException)
        {
            return new { ok = false, message = e is NotConfiguredException ? "address or key missing" : e.Message };
        }
    }

    private static async Task<string?> QbitVersion(HttpClient http, TestRequest t, string password, CancellationToken ct)
    {
        var qbit = new QbitClient(http, t.Url, t.Username, password);
        return await qbit.Version(ct).ConfigureAwait(false);
    }
}
