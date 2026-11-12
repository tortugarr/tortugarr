using System.Collections.Concurrent;
using System.Text.Json.Nodes;
using Jellyfin.Data.Enums;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.TV;
using MediaBrowser.Controller.Library;
using MediaBrowser.Model.Entities;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Real top lists as home rows (2026-11-08): this week's most watched films and shows, the IMDb
/// Top 250 and new digital releases, read from public MDBList lists (no key needed; the lists
/// are set in TopLists, one "Title|user/list" per line, because they are kept by MDBList users
/// and may move). Each title gets its poster from Seerr and, when the user has it, the library
/// item id, so the app opens it directly; the rest can be downloaded.
/// </summary>
public sealed class TopListService
{
    private static readonly TimeSpan ListCacheFor = TimeSpan.FromHours(6);
    private static readonly TimeSpan DetailCacheFor = TimeSpan.FromDays(3);
    private const string TmdbImages = "https://image.tmdb.org/t/p/";

    private readonly TortugarrService _svc;
    private readonly ILibraryManager _library;
    private readonly IUserManager _users;
    private readonly ILogger<TopListService> _log;
    private readonly ConcurrentDictionary<string, (DateTimeOffset At, JsonArray Items)> _lists = new();
    private readonly ConcurrentDictionary<string, (DateTimeOffset At, JsonNode? Detail)> _details = new();

    public TopListService(TortugarrService svc, ILibraryManager library, IUserManager users, ILogger<TopListService> log)
    {
        _svc = svc;
        _library = library;
        _users = users;
        _log = log;
        AddNewDefaultLists(Plugin.Instance);
    }

    /// <summary>The four lists 1.3.0.25 to 1.3.0.36 shipped with. A server that still has exactly
    /// these gets the lists added in 4.20.04 (Trending, Netflix Top 10, Rotten Tomatoes,
    /// Certified Fresh); a list the user changed is left alone.</summary>
    internal const string FirstDefaultLists =
        "Most watched films this week|linaspurinis/top-watched-movies-of-the-week\n" +
        "Most watched shows this week|jah57/trakt-most-watched-shows-of-the-week\n" +
        "New on digital|snoak/latest-movies-digital-release\n" +
        "IMDb Top 250|georgenilas/imdb-top-250";

    internal static bool AddNewDefaultLists(Configuration.PluginConfiguration c)
    {
        if ((c.TopLists ?? string.Empty).Replace("\r", string.Empty).Trim() != FirstDefaultLists)
        {
            return false;
        }

        c.TopLists = new Configuration.PluginConfiguration().TopLists;
        return true;
    }

    private static void AddNewDefaultLists(Plugin? plugin)
    {
        if (plugin is not null && AddNewDefaultLists(plugin.Configuration))
        {
            plugin.SaveConfiguration();
        }
    }

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    /// <summary>"Title|user/list" lines; blank lines, "#" comments and lines without a list are skipped.</summary>
    internal static List<TopListDef> Parse(string? text) =>
        (text ?? string.Empty).Split('\n')
            .Select(l => l.Trim())
            .Where(l => l.Length > 0 && !l.StartsWith('#'))
            .Select(l => l.Split('|', 2))
            .Where(p => p.Length == 2 && p[0].Trim().Length > 0 && System.Text.RegularExpressions.Regex.IsMatch(p[1].Trim(), @"^[\w.-]+/[\w.-]+$"))
            .Select((p, i) => new TopListDef(i, p[0].Trim(), p[1].Trim()))
            .ToList();

    public object Lists() => Parse(Cfg.TopLists).Select(l => new { index = l.Index, title = l.Title }).ToList();

    public async Task<object> GetAsync(int index, int limit, Guid userId, CancellationToken ct)
    {
        var def = Parse(Cfg.TopLists).FirstOrDefault(l => l.Index == index) ?? throw new KeyNotFoundException("no such top list");
        var entries = Entries(await Fetch(def.Slug, ct).ConfigureAwait(false)).Take(Math.Clamp(limit, 1, 100)).ToList();
        var owned = Owned(userId);
        using var gate = new SemaphoreSlim(6);
        var items = await Task.WhenAll(entries.Select(async e =>
        {
            await gate.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                var d = await Detail(e, ct).ConfigureAwait(false);
                var poster = (string?)d?["posterPath"];
                var backdrop = (string?)d?["backdropPath"];
                owned.TryGetValue((e.MediaType, e.MediaType == "tv" ? e.TvdbId ?? -1 : e.TmdbId), out var itemId);
                return new
                {
                    tmdbId = e.TmdbId,
                    tvdbId = e.TvdbId,
                    imdbId = e.ImdbId,
                    mediaType = e.MediaType,
                    title = e.Title,
                    year = e.Year,
                    overview = (string?)d?["overview"],
                    posterUrl = poster is null ? null : TmdbImages + "w342" + poster,
                    backdropUrl = backdrop is null ? null : TmdbImages + "w780" + backdrop,
                    libraryItemId = itemId == Guid.Empty ? null : itemId.ToString("N"),
                };
            }
            finally
            {
                gate.Release();
            }
        })).ConfigureAwait(false);
        return new { index = def.Index, title = def.Title, items };
    }

    /// <summary>MDBList entries with a TMDB id, in list order; "show" becomes "tv".</summary>
    internal static List<TopEntry> Entries(JsonArray list) =>
        list.Where(n => n is not null && (int?)n["id"] > 0 && (int?)n["adult"] != 1)
            .Select(n => new TopEntry(
                (int)n!["id"]!,
                (int?)n["tvdbid"] is > 0 ? (int?)n["tvdbid"] : null,
                (string?)n["imdb_id"],
                ((string?)n["mediatype"]) == "show" ? "tv" : "movie",
                (string?)n["title"] ?? string.Empty,
                (int?)n["release_year"]))
            .ToList();

    private async Task<JsonArray> Fetch(string slug, CancellationToken ct)
    {
        if (_lists.TryGetValue(slug, out var hit) && DateTimeOffset.UtcNow - hit.At < ListCacheFor)
        {
            return hit.Items;
        }

        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, $"https://mdblist.com/lists/{slug}/json");
            req.Headers.UserAgent.ParseAdd("Tortugarr");
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(TimeSpan.FromSeconds(15));
            using var res = await _svc.Http.SendAsync(req, cts.Token).ConfigureAwait(false);
            var node = JsonNode.Parse(await res.Content.ReadAsStringAsync(cts.Token).ConfigureAwait(false)) as JsonArray
                       ?? throw new InvalidDataException("not a list");
            _lists[slug] = (DateTimeOffset.UtcNow, node);
            return node;
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _log.LogWarning("Tortugarr: top list {Slug} unavailable: {Message}", slug, e.Message);
            if (hit.Items is not null)
            {
                return hit.Items; // an old copy beats an empty row
            }

            throw new UpstreamException("MDBList", $"the list {slug} is unavailable");
        }
    }

    private async Task<JsonNode?> Detail(TopEntry e, CancellationToken ct)
    {
        var key = $"{e.MediaType}/{e.TmdbId}";
        if (_details.TryGetValue(key, out var hit) && DateTimeOffset.UtcNow - hit.At < DetailCacheFor)
        {
            return hit.Detail;
        }

        try
        {
            var d = await _svc.Seerr.Get($"/{e.MediaType}/{e.TmdbId}", ct, 10).ConfigureAwait(false);
            var slim = new JsonObject
            {
                ["posterPath"] = (string?)d?["posterPath"],
                ["backdropPath"] = (string?)d?["backdropPath"],
                ["overview"] = (string?)d?["overview"],
            };
            _details[key] = (DateTimeOffset.UtcNow, slim);
            return slim;
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _log.LogDebug(ex, "Tortugarr: no Seerr details for {Key}", key);
            return null;
        }
    }

    /// <summary>The user's movies by TMDB id and series by TVDB id, from the libraries they may see.</summary>
    private Dictionary<(string, int), Guid> Owned(Guid userId)
    {
        var map = new Dictionary<(string, int), Guid>();
        var user = userId == Guid.Empty ? null : _users.GetUserById(userId); // an API key has no user
        var query = user is null ? new InternalItemsQuery() : new InternalItemsQuery(user);
        query.IncludeItemTypes = new[] { BaseItemKind.Movie, BaseItemKind.Series };
        query.Recursive = true;
        foreach (var i in _library.GetItemList(query))
        {
            if (i is Series && int.TryParse(i.GetProviderId(MetadataProvider.Tvdb), out var tv))
            {
                map.TryAdd(("tv", tv), i.Id);
            }
            else if (i is not Series && int.TryParse(i.GetProviderId(MetadataProvider.Tmdb), out var tm))
            {
                map.TryAdd(("movie", tm), i.Id);
            }
        }

        return map;
    }
}

internal sealed record TopListDef(int Index, string Title, string Slug);

internal sealed record TopEntry(int TmdbId, int? TvdbId, string? ImdbId, string MediaType, string Title, int? Year);
