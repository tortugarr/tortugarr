using Jellyfin.Database.Implementations.Entities;
using MediaBrowser.Model.Activity;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Writes an entry to Jellyfin's activity log, which the app's administration page shows.
/// Used for things the administrator should know about without opening a log: a Moonbase
/// update held back, a qBittorrent repair. The same text is not written twice in a row.
/// </summary>
public sealed class AdminNotice
{
    private readonly IActivityManager _activity;
    private readonly ILogger<AdminNotice> _log;
    private readonly Dictionary<string, string> _last = new(StringComparer.Ordinal);

    public AdminNotice(IActivityManager activity, ILogger<AdminNotice> log)
    {
        _activity = activity;
        _log = log;
    }

    /// <summary>Posts the notice unless the last one of this kind had the same text.</summary>
    public async Task PostAsync(string kind, string name, string overview, LogLevel severity)
    {
        lock (_last)
        {
            if (_last.TryGetValue(kind, out var previous) && previous == name + overview)
            {
                return;
            }

            _last[kind] = name + overview;
        }

        try
        {
            await _activity.CreateAsync(new ActivityLog(name, "Tortugarr" + kind, Guid.Empty)
            {
                ShortOverview = overview.Length > 200 ? overview[..200] : overview,
                Overview = overview,
                LogSeverity = severity,
            }).ConfigureAwait(false);
        }
        catch (Exception e)
        {
            _log.LogDebug(e, "Tortugarr: activity log entry not written");
        }
    }
}
