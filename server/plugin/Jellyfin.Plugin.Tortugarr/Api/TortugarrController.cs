using System.Net.Mime;
using System.Security.Claims;
using System.Text.Json;
using Jellyfin.Plugin.Tortugarr.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Jellyfin.Plugin.Tortugarr.Api;

/// <summary>
/// The routes of docs/design/tortugarr-plugin-api.md. Every route needs a Jellyfin session;
/// everything except Capabilities needs an administrator (version 1), except that a limited
/// downloader (a non-administrator with download limits) may search, grab and see a series.
/// </summary>
[ApiController]
[Authorize]
[Route("Tortugarr/v1")]
[Produces(MediaTypeNames.Application.Json)]
public class TortugarrController : ControllerBase
{
    private const string Admin = "RequiresElevation";
    private static readonly JsonSerializerOptions Camel = new(JsonSerializerDefaults.Web);
    private readonly TortugarrService _svc;
    private readonly LibraryDeleteService _delete;
    private readonly ArrHookService _hook;
    private readonly SeriesService _series;
    private readonly SpaceService _space;
    private readonly UserLimitService _limits;

    public TortugarrController(TortugarrService svc, LibraryDeleteService delete, ArrHookService hook, SeriesService series, SpaceService space, UserLimitService limits)
    {
        _svc = svc;
        _delete = delete;
        _hook = hook;
        _series = series;
        _space = space;
        _limits = limits;
    }

    private Guid UserId
    {
        get
        {
            var v = User.FindFirst("Jellyfin-UserId")?.Value ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return Guid.TryParse(v, out var id) ? id : Guid.Empty;
        }
    }

    private bool IsAdmin => User.IsInRole("Administrator");

    /// <summary>An administrator, or a limited downloader (whose limits come back in <paramref name="limit"/>).</summary>
    private bool MayDownload(out Configuration.UserLimit? limit)
    {
        limit = IsAdmin ? null : _limits.For(UserId);
        return IsAdmin || limit is not null;
    }

    private static ContentResult NotAllowed() =>
        Error(403, "forbidden", "downloading needs an administrator or download limits set by one");

    // Jellyfin answers in PascalCase; the spec says camelCase, so these routes serialize themselves.
    private static ContentResult Json(object? body, int status = 200) => new()
    {
        StatusCode = status,
        ContentType = "application/json; charset=utf-8",
        Content = body is null ? string.Empty : JsonSerializer.Serialize(body, Camel),
    };

    private static ContentResult Error(int status, string code, string message) =>
        Json(new { error = new { code, message } }, status);

    private async Task<IActionResult> Run(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action().ConfigureAwait(false);
        }
        catch (ArgumentException e)
        {
            return Error(400, "bad_request", e.Message);
        }
        catch (KeyNotFoundException e)
        {
            return Error(404, "not_found", e.Message);
        }
        catch (FeatureOffException e)
        {
            return Error(403, "feature_off", e.Message);
        }
        catch (SearchExpiredException e)
        {
            return Error(409, "search_expired", e.Message);
        }
        catch (ConflictException e)
        {
            return Error(409, e.Code, e.Message);
        }
        catch (AlreadyInClientException e)
        {
            return Json(new { error = new { code = "already_in_client", message = e.Message, downloadId = e.DownloadId, category = e.Category, progress = e.Progress, state = e.State } }, 409);
        }
        catch (LimitException e)
        {
            return Error(403, e.Code, e.Message);
        }
        catch (NotConfiguredException e)
        {
            return Error(503, "not_configured", e.Message);
        }
        catch (UpstreamException e)
        {
            return Error(502, "upstream_failed", e.Message);
        }
    }

    /// <summary>3.1 - what this user may do on this server. Any logged-in user.</summary>
    [HttpGet("Capabilities")]
    public Task<IActionResult> Capabilities() =>
        Run(async () => Json(await _svc.CapabilitiesAsync(IsAdmin, UserId).ConfigureAwait(false)));

    /// <summary>3.2 - start a search (asynchronous).</summary>
    [HttpPost("Searches")]
    public Task<IActionResult> StartSearch([FromBody] SearchRequest req) => Run(() =>
    {
        if (!MayDownload(out var limit))
        {
            return Task.FromResult<IActionResult>(NotAllowed());
        }

        var job = _svc.StartSearch(UserId, req, limit);
        return Task.FromResult<IActionResult>(Json(new { searchId = job.Id, pollAfterSeconds = 2 }, StatusCodes.Status202Accepted));
    });

    /// <summary>3.2 - how a search is doing, and its result.</summary>
    [HttpGet("Searches/{searchId}")]
    public IActionResult GetSearch([FromRoute] string searchId)
    {
        if (!MayDownload(out _))
        {
            return NotAllowed();
        }

        var job = _svc.GetJob(UserId, searchId);
        if (job is null)
        {
            return Error(404, "not_found", "no such search (finished searches are kept 30 minutes)");
        }

        return job.Status switch
        {
            "running" => Json(new { status = "running", elapsedSeconds = (int)(DateTimeOffset.UtcNow - job.Started).TotalSeconds }),
            "done" => Json(new { status = "done", result = job.Result }),
            _ => Json(new { status = "failed", error = new { code = job.ErrorCode, message = job.ErrorMessage } }),
        };
    }

    /// <summary>3.2 - the user cancelled: stop the search.</summary>
    [HttpDelete("Searches/{searchId}")]
    public IActionResult CancelSearch([FromRoute] string searchId) =>
        !MayDownload(out _) ? NotAllowed()
        : _svc.CancelSearch(UserId, searchId)
            ? NoContent()
            : Error(404, "not_found", "no such search (finished searches are kept 30 minutes)");

    /// <summary>3.3 - download a release the user was shown.</summary>
    [HttpPost("Grab")]
    public Task<IActionResult> Grab([FromBody] TortugarrService.GrabRequest req) =>
        Run(async () => MayDownload(out _)
            ? Json(await _svc.Grab(UserId, req, HttpContext.RequestAborted).ConfigureAwait(false))
            : NotAllowed());

    /// <summary>3.4 - what is downloading.</summary>
    [HttpGet("Downloads")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> Downloads() =>
        Run(async () => Json(await _svc.Downloads(HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.5 - remove a download (and blocklist the release when asked).</summary>
    [HttpDelete("Downloads/{downloadId}")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> Remove([FromRoute] string downloadId, [FromQuery] bool blocklist = false) => Run(async () =>
    {
        await _svc.Remove(downloadId, blocklist, HttpContext.RequestAborted).ConfigureAwait(false);
        return NoContent();
    });

    /// <summary>3.10 - delete a movie, episode, season or series from the library (as the app does).</summary>
    [HttpDelete("Library/{itemId}")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> DeleteTitle([FromRoute] Guid itemId) =>
        Run(async () => Json(await _delete.DeleteAsync(itemId, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>
    /// 3.12 - Radarr's/Sonarr's webhook: refresh only what changed (server to server). Only the
    /// shared hook key opens it, not a Jellyfin session, so Radarr/Sonarr never hold a Jellyfin
    /// administrator key.
    /// </summary>
    [HttpPost("Hooks/Arr")]
    [AllowAnonymous]
    public Task<IActionResult> ArrHook([FromBody] System.Text.Json.Nodes.JsonObject body) => Run(async () =>
    {
        if (!HookKeyOk(Plugin.Instance?.Configuration.HookKey, Request.Headers["X-Tortugarr-Hook-Key"].ToString()))
        {
            return Error(401, "bad_hook_key", "missing or wrong X-Tortugarr-Hook-Key");
        }

        await _hook.HandleAsync(body).ConfigureAwait(false);
        return NoContent();
    });

    /// <summary>Constant-time check; an empty configured key opens nothing.</summary>
    internal static bool HookKeyOk(string? configured, string? sent) =>
        !string.IsNullOrEmpty(configured) && !string.IsNullOrEmpty(sent)
        && System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(
            System.Text.Encoding.UTF8.GetBytes(configured), System.Text.Encoding.UTF8.GetBytes(sent));

    /// <summary>3.14 - a series as Sonarr sees it, with the queue (missing-episodes view).</summary>
    [HttpGet("Series/{tvdbId:int}")]
    public Task<IActionResult> Series([FromRoute] int tvdbId) =>
        Run(async () => MayDownload(out _)
            ? Json(await _series.GetAsync(tvdbId, HttpContext.RequestAborted).ConfigureAwait(false))
            : NotAllowed());

    /// <summary>A user's download limits and what they used this week (administrator).</summary>
    [HttpGet("Users/{userId:guid}/Limits")]
    [Authorize(Policy = Admin)]
    public IActionResult GetLimits([FromRoute] Guid userId)
    {
        var all = Plugin.Instance?.Configuration.UserLimits ?? Array.Empty<Configuration.UserLimit>();
        var limit = UserLimitService.Find(all, userId) ?? new Configuration.UserLimit { UserId = userId.ToString("N") };
        var (movies, episodes) = _limits.Used(userId, DateTimeOffset.UtcNow);
        return Json(new
        {
            enabled = limit.Enabled,
            maxMovieMb = limit.MaxMovieMb,
            maxEpisodeMb = limit.MaxEpisodeMb,
            moviesPerWeek = limit.MoviesPerWeek,
            episodesPerWeek = limit.EpisodesPerWeek,
            moviesUsed = movies,
            episodesUsed = episodes,
        });
    }

    /// <summary>Sets a user's download limits (administrator). Has no effect on administrators.</summary>
    [HttpPut("Users/{userId:guid}/Limits")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SetLimits([FromRoute] Guid userId, [FromBody] Configuration.UserLimit limit) => Run(() =>
    {
        _limits.Set(userId, limit);
        return Task.FromResult<IActionResult>(GetLimits(userId));
    });

    /// <summary>3.14 - switch a season's monitoring, the app's way.</summary>
    [HttpPut("Series/{tvdbId:int}/Seasons/{seasonNumber:int}")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> Season([FromRoute] int tvdbId, [FromRoute] int seasonNumber, [FromBody] SeriesService.SeasonRequest req) =>
        Run(async () => Json(await _series.SetSeasonAsync(tvdbId, seasonNumber, req, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.15 - what can go to free space (duplicates and titles with activity).</summary>
    [HttpGet("Space/Candidates")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SpaceCandidates() =>
        Run(async () => Json(await _space.CandidatesAsync(HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.15 - remove a duplicate torrent (already imported) with its files.</summary>
    [HttpDelete("Space/Duplicates/{hash}")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> DeleteDuplicate([FromRoute] string hash) => Run(async () =>
    {
        await _space.DeleteDuplicateAsync(hash, HttpContext.RequestAborted).ConfigureAwait(false);
        return NoContent();
    });

    /// <summary>3.15 - is there room for a release of this size?</summary>
    [HttpGet("Space/Check")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SpaceCheck([FromQuery] long bytes) =>
        Run(async () => Json(await _space.CheckAsync(bytes, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.6 - is there a video in it? Removes and blocklists it when not.</summary>
    [HttpPost("Downloads/{downloadId}/Check")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> Check([FromRoute] string downloadId) =>
        Run(async () => Json(await _svc.Check(downloadId, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.7 - free space where downloads land.</summary>
    [HttpGet("Space")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> Space() =>
        Run(async () => Json(await _svc.Space(HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.8 - Bazarr's manual subtitle search for a movie or an episode.</summary>
    [HttpGet("Subtitles")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SubtitleSearch([FromQuery] string type, [FromQuery] int? tmdbId, [FromQuery] int? tvdbId, [FromQuery] int? season, [FromQuery] int? episode) =>
        Run(async () => Json(await _svc.SubtitleSearch(type, tmdbId, tvdbId, season, episode, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.8 - which languages the Bazarr profile wants are there, and which are missing.</summary>
    [HttpGet("Subtitles/State")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SubtitleState([FromQuery] string type, [FromQuery] int? tmdbId, [FromQuery] int? tvdbId, [FromQuery] int? season, [FromQuery] int? episode) =>
        Run(async () => Json(await _svc.SubtitleState(type, tmdbId, tvdbId, season, episode, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.8 - Bazarr's automatic search for missing languages (in the background).</summary>
    [HttpPost("Subtitles/Search")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SubtitleSearchMissing([FromBody] TortugarrService.SubtitleSearchRequest req) => Run(async () =>
    {
        await _svc.SubtitleSearchMissing(req, HttpContext.RequestAborted).ConfigureAwait(false);
        return Json(new { status = "searching" }, StatusCodes.Status202Accepted);
    });

    /// <summary>3.9 - adult library search (asynchronous; only when switched on).</summary>
    [HttpPost("Adult/Searches")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> AdultSearch([FromBody] AdultSearchBody body) => Run(async () =>
    {
        var job = await _svc.StartAdultSearch(UserId, body.Query).ConfigureAwait(false);
        return Json(new { searchId = job.Id, pollAfterSeconds = 2 }, StatusCodes.Status202Accepted);
    });

    /// <summary>3.9 - how an adult search is doing, and its result.</summary>
    [HttpGet("Adult/Searches/{searchId}")]
    [Authorize(Policy = Admin)]
    public IActionResult AdultSearchStatus([FromRoute] string searchId)
    {
        if (!TortugarrService.AdultReady(Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration()))
        {
            return Error(403, "feature_off", "the adult library is switched off on this server");
        }

        var job = _svc.GetJob(UserId, searchId);
        if (job is null || job.Request.Type != "adult")
        {
            return Error(404, "not_found", "no such search (finished searches are kept 30 minutes)");
        }

        return job.Status switch
        {
            "running" => Json(new { status = "running", elapsedSeconds = (int)(DateTimeOffset.UtcNow - job.Started).TotalSeconds }),
            "done" => Json(new { status = "done", result = job.Result }),
            _ => Json(new { status = "failed", error = new { code = job.ErrorCode, message = job.ErrorMessage } }),
        };
    }

    /// <summary>3.9 - take an adult release (straight to qBittorrent, its own category and folder).</summary>
    [HttpPost("Adult/Grab")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> AdultGrab([FromBody] TortugarrService.AdultGrabRequest req) =>
        Run(async () => Json(await _svc.AdultGrab(UserId, req, HttpContext.RequestAborted).ConfigureAwait(false)));

    /// <summary>3.8 - download one of the candidates; Bazarr saves it next to the video.</summary>
    [HttpPost("Subtitles")]
    [Authorize(Policy = Admin)]
    public Task<IActionResult> SubtitleGet([FromBody] TortugarrService.SubtitleDownload req) => Run(async () =>
    {
        await _svc.SubtitleGet(req, HttpContext.RequestAborted).ConfigureAwait(false);
        return NoContent();
    });
}

/// <summary>Body of POST Adult/Searches.</summary>
public sealed class AdultSearchBody
{
    public string Query { get; set; } = string.Empty;
}
