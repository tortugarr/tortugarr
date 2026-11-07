using System.Buffers.Binary;
using System.Net;
using System.Net.Sockets;
using System.Text;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Asks the trackers how many peers a torrent has right now, instead of trusting the number
/// the indexer cached (2026-11-07: "as autonomous as possible" - dead torrents should be seen
/// before the grab, not after hours of "stalled"). UDP (BEP 15) and HTTP scrape, many hashes
/// per request, all trackers at once, within a short time budget.
///
/// Only an answer from one of the torrent's own trackers (from its magnet) can call it dead:
/// the public trackers asked on top say 0 for a torrent they never saw, so their zero means
/// "unknown", while their seeders count.
/// </summary>
public sealed class LiveSeedCheck
{
    /// <summary>Big public trackers asked for every hash, also for releases without a magnet.</summary>
    internal static readonly string[] PublicTrackers =
    {
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://open.stealth.si:80/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://exodus.desync.com:6969/announce",
        "udp://open.demonii.com:1337/announce",
        "udp://tracker.dler.org:6969/announce",
    };

    internal const int MaxTrackers = 16;
    private const int HashesPerRequest = 70; // a UDP scrape of 74 hashes still fits one packet
    private const long UdpProtocolId = 0x41727101980;

    private readonly HttpClient _http;
    private readonly ILogger _log;

    public LiveSeedCheck(HttpClient http, ILogger log)
    {
        _http = http;
        _log = log;
    }

    /// <summary>One torrent to check: its info hash (40 hex) and the trackers from its magnet.</summary>
    internal sealed record Item(string Hash, IReadOnlyList<string> Trackers);

    /// <summary>What the trackers said about one hash.</summary>
    internal sealed class Answer
    {
        public int Seeders { get; set; }

        public int Leechers { get; set; }

        /// <summary>One of the torrent's own trackers answered.</summary>
        public bool OwnTrackerAnswered { get; set; }
    }

    /// <summary>Live peer counts per hash; a hash no tracker answered for is left out.</summary>
    internal async Task<Dictionary<string, Answer>> CheckAsync(IReadOnlyCollection<Item> items, TimeSpan budget, CancellationToken ct, IReadOnlyList<string>? publicTrackers = null)
    {
        var extra = publicTrackers ?? PublicTrackers;
        var answers = new Dictionary<string, Answer>(StringComparer.OrdinalIgnoreCase);
        if (items.Count == 0)
        {
            return answers;
        }

        // Tracker -> hashes; the torrents' own trackers first (most used first), then the public ones.
        var own = items.SelectMany(i => i.Trackers.Select(t => (Tracker: t, i.Hash)))
            .GroupBy(x => x.Tracker, StringComparer.OrdinalIgnoreCase)
            .OrderByDescending(g => g.Count())
            .Take(Math.Max(0, MaxTrackers - extra.Count))
            .ToDictionary(g => g.Key, g => g.Select(x => x.Hash).Distinct(StringComparer.OrdinalIgnoreCase).ToList(), StringComparer.OrdinalIgnoreCase);
        var plan = new Dictionary<string, List<string>>(own, StringComparer.OrdinalIgnoreCase);
        var allHashes = items.Select(i => i.Hash).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        foreach (var t in extra)
        {
            plan[t] = plan.TryGetValue(t, out var have) ? have.Union(allHashes, StringComparer.OrdinalIgnoreCase).ToList() : allHashes;
        }

        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(budget);
        var tasks = plan.Select(async p =>
        {
            var got = new Dictionary<string, (int S, int L)>(StringComparer.OrdinalIgnoreCase);
            foreach (var chunk in p.Value.Chunk(HashesPerRequest))
            {
                try
                {
                    foreach (var kv in await ScrapeAsync(p.Key, chunk, cts.Token).ConfigureAwait(false))
                    {
                        got[kv.Key] = kv.Value;
                    }
                }
                catch (Exception e) when (e is not OutOfMemoryException)
                {
                    break; // a slow or dead tracker: the others still count
                }
            }

            return (Tracker: p.Key, Got: got);
        }).ToList();

        var done = await Task.WhenAll(tasks).ConfigureAwait(false);
        var ownOf = items.GroupBy(i => i.Hash, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.SelectMany(i => i.Trackers).ToHashSet(StringComparer.OrdinalIgnoreCase), StringComparer.OrdinalIgnoreCase);
        foreach (var (tracker, got) in done)
        {
            foreach (var (hash, (s, l)) in got)
            {
                if (!answers.TryGetValue(hash, out var a))
                {
                    answers[hash] = a = new Answer();
                }

                a.Seeders = Math.Max(a.Seeders, s);
                a.Leechers = Math.Max(a.Leechers, l);
                if (ownOf.TryGetValue(hash, out var mine) && mine.Contains(tracker))
                {
                    a.OwnTrackerAnswered = true;
                }
            }
        }

        _log.LogInformation("Tortugarr live seeds: {Hashes} torrent(s), {Trackers} tracker(s) asked, {Answered} answered, {Alive} with seeders",
            allHashes.Count, plan.Count, done.Count(d => d.Got.Count > 0), answers.Count(a => a.Value.Seeders > 0));
        return answers;
    }

    private Task<Dictionary<string, (int, int)>> ScrapeAsync(string tracker, IReadOnlyList<string> hashes, CancellationToken ct)
    {
        if (tracker.StartsWith("udp://", StringComparison.OrdinalIgnoreCase))
        {
            return UdpScrapeAsync(tracker, hashes, ct);
        }

        return HttpScrapeAsync(tracker, hashes, ct);
    }

    private static async Task<Dictionary<string, (int, int)>> UdpScrapeAsync(string tracker, IReadOnlyList<string> hashes, CancellationToken ct)
    {
        var uri = new Uri(tracker);
        using var udp = new UdpClient(AddressFamily.InterNetwork);
        var addresses = await Dns.GetHostAddressesAsync(uri.Host, AddressFamily.InterNetwork, ct).ConfigureAwait(false);
        if (addresses.Length == 0)
        {
            return new();
        }

        udp.Connect(new IPEndPoint(addresses[0], uri.Port));
        var tid = Random.Shared.Next();
        await udp.SendAsync(ConnectRequest(tid), ct).ConfigureAwait(false);
        var conn = ParseConnect((await udp.ReceiveAsync(ct).ConfigureAwait(false)).Buffer, tid)
                   ?? throw new InvalidDataException("bad connect answer");
        tid = Random.Shared.Next();
        var raw = hashes.Select(HexToBytes).ToList();
        await udp.SendAsync(ScrapeRequest(conn, tid, raw), ct).ConfigureAwait(false);
        var counts = ParseScrape((await udp.ReceiveAsync(ct).ConfigureAwait(false)).Buffer, tid, raw.Count)
                     ?? throw new InvalidDataException("bad scrape answer");
        var result = new Dictionary<string, (int, int)>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < counts.Count; i++)
        {
            result[hashes[i]] = (counts[i].Seeders, counts[i].Leechers);
        }

        return result;
    }

    private async Task<Dictionary<string, (int, int)>> HttpScrapeAsync(string tracker, IReadOnlyList<string> hashes, CancellationToken ct)
    {
        var url = ScrapeUrl(tracker);
        if (url is null)
        {
            return new();
        }

        var query = string.Join("&", hashes.Select(h => "info_hash=" + PercentEncode(HexToBytes(h))));
        using var resp = await _http.GetAsync(url + (url.Contains('?') ? "&" : "?") + query, ct).ConfigureAwait(false);
        if (!resp.IsSuccessStatusCode)
        {
            return new();
        }

        var body = await resp.Content.ReadAsByteArrayAsync(ct).ConfigureAwait(false);
        return ParseHttpScrape(body);
    }

    // ------------------------------------------------------------------ magnets and hashes

    /// <summary>The info hash as 40 lowercase hex: the indexer's, else the magnet's (hex or base32).</summary>
    internal static string? HashOf(string? infoHash, string? magnet)
    {
        var h = Normalize(infoHash);
        if (h is not null || string.IsNullOrWhiteSpace(magnet))
        {
            return h;
        }

        var m = System.Text.RegularExpressions.Regex.Match(magnet, @"xt=urn:btih:([A-Za-z0-9]+)", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        return m.Success ? Normalize(m.Groups[1].Value) : null;
    }

    private static string? Normalize(string? h)
    {
        h = h?.Trim();
        if (string.IsNullOrEmpty(h))
        {
            return null;
        }

        if (h.Length == 40 && h.All(Uri.IsHexDigit))
        {
            return h.ToLowerInvariant();
        }

        if (h.Length == 32)
        {
            var bytes = Base32(h);
            return bytes is null ? null : Convert.ToHexString(bytes).ToLowerInvariant();
        }

        return null;
    }

    private static byte[]? Base32(string s)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        var bits = 0;
        var value = 0;
        var output = new List<byte>(20);
        foreach (var ch in s.ToUpperInvariant())
        {
            var idx = alphabet.IndexOf(ch, StringComparison.Ordinal);
            if (idx < 0)
            {
                return null;
            }

            value = (value << 5) | idx;
            bits += 5;
            if (bits >= 8)
            {
                output.Add((byte)((value >> (bits - 8)) & 0xFF));
                bits -= 8;
            }
        }

        return output.Count == 20 ? output.ToArray() : null;
    }

    /// <summary>The magnet's udp/http(s) trackers ("tr=" parameters).</summary>
    internal static List<string> TrackersOf(string? magnet)
    {
        var list = new List<string>();
        if (string.IsNullOrWhiteSpace(magnet) || !magnet.StartsWith("magnet:", StringComparison.OrdinalIgnoreCase))
        {
            return list;
        }

        var q = magnet.IndexOf('?');
        foreach (var part in magnet[(q + 1)..].Split('&'))
        {
            if (!part.StartsWith("tr=", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var t = Uri.UnescapeDataString(part[3..].Replace('+', ' ')).Trim();
            if ((t.StartsWith("udp://", StringComparison.OrdinalIgnoreCase) || t.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
                 || t.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) && Uri.TryCreate(t, UriKind.Absolute, out var u) && u.Port > 0
                && !list.Contains(t, StringComparer.OrdinalIgnoreCase))
            {
                list.Add(t);
            }
        }

        return list;
    }

    internal static byte[] HexToBytes(string hex) => Convert.FromHexString(hex);

    // ------------------------------------------------------------------ UDP tracker protocol (BEP 15)

    internal static byte[] ConnectRequest(int tid)
    {
        var b = new byte[16];
        BinaryPrimitives.WriteInt64BigEndian(b, UdpProtocolId);
        BinaryPrimitives.WriteInt32BigEndian(b.AsSpan(8), 0);
        BinaryPrimitives.WriteInt32BigEndian(b.AsSpan(12), tid);
        return b;
    }

    internal static long? ParseConnect(byte[] r, int tid) =>
        r.Length >= 16 && BinaryPrimitives.ReadInt32BigEndian(r) == 0 && BinaryPrimitives.ReadInt32BigEndian(r.AsSpan(4)) == tid
            ? BinaryPrimitives.ReadInt64BigEndian(r.AsSpan(8))
            : null;

    internal static byte[] ScrapeRequest(long connectionId, int tid, IReadOnlyList<byte[]> hashes)
    {
        var b = new byte[16 + (20 * hashes.Count)];
        BinaryPrimitives.WriteInt64BigEndian(b, connectionId);
        BinaryPrimitives.WriteInt32BigEndian(b.AsSpan(8), 2);
        BinaryPrimitives.WriteInt32BigEndian(b.AsSpan(12), tid);
        for (var i = 0; i < hashes.Count; i++)
        {
            hashes[i].CopyTo(b, 16 + (20 * i));
        }

        return b;
    }

    internal static List<(int Seeders, int Completed, int Leechers)>? ParseScrape(byte[] r, int tid, int count)
    {
        if (r.Length < 8 || BinaryPrimitives.ReadInt32BigEndian(r) != 2 || BinaryPrimitives.ReadInt32BigEndian(r.AsSpan(4)) != tid)
        {
            return null;
        }

        var list = new List<(int, int, int)>();
        for (var i = 0; i < count && 8 + (12 * (i + 1)) <= r.Length; i++)
        {
            var o = 8 + (12 * i);
            list.Add((BinaryPrimitives.ReadInt32BigEndian(r.AsSpan(o)), BinaryPrimitives.ReadInt32BigEndian(r.AsSpan(o + 4)),
                BinaryPrimitives.ReadInt32BigEndian(r.AsSpan(o + 8))));
        }

        return list;
    }

    // ------------------------------------------------------------------ HTTP scrape

    /// <summary>The scrape URL for an HTTP announce URL (".../announce" -> ".../scrape"); null when it has none.</summary>
    internal static string? ScrapeUrl(string announce)
    {
        var q = announce.IndexOf('?');
        var path = q < 0 ? announce : announce[..q];
        var slash = path.LastIndexOf('/');
        if (slash < 0 || !path[(slash + 1)..].StartsWith("announce", StringComparison.Ordinal))
        {
            return null;
        }

        return path[..(slash + 1)] + "scrape" + path[(slash + 1 + "announce".Length)..] + (q < 0 ? string.Empty : announce[q..]);
    }

    private static string PercentEncode(byte[] bytes)
    {
        var sb = new StringBuilder(bytes.Length * 3);
        foreach (var b in bytes)
        {
            var c = (char)b;
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c is '-' or '_' or '.' or '~')
            {
                sb.Append(c);
            }
            else
            {
                sb.Append('%').Append(b.ToString("X2", System.Globalization.CultureInfo.InvariantCulture));
            }
        }

        return sb.ToString();
    }

    /// <summary>Reads "d5:filesd20:&lt;hash&gt;d8:completei5e10:incompletei2e...eee".</summary>
    internal static Dictionary<string, (int, int)> ParseHttpScrape(byte[] body)
    {
        var result = new Dictionary<string, (int, int)>(StringComparer.OrdinalIgnoreCase);
        var pos = 0;
        if (Decode(body, ref pos) is not Dictionary<string, object> root || !root.TryGetValue("files", out var f) || f is not Dictionary<string, object> files)
        {
            return result;
        }

        foreach (var (key, v) in files)
        {
            if (v is not Dictionary<string, object> d)
            {
                continue;
            }

            var hash = Convert.ToHexString(Encoding.Latin1.GetBytes(key)).ToLowerInvariant();
            var s = d.TryGetValue("complete", out var c) && c is long cl ? (int)cl : 0;
            var l = d.TryGetValue("incomplete", out var i) && i is long il ? (int)il : 0;
            result[hash] = (s, l);
        }

        return result;
    }

    /// <summary>Minimal bencode: dictionary keys and strings as Latin-1 (keeps the 20 raw hash bytes).</summary>
    private static object? Decode(byte[] b, ref int pos)
    {
        if (pos >= b.Length)
        {
            return null;
        }

        switch ((char)b[pos])
        {
            case 'i':
            {
                var end = Array.IndexOf(b, (byte)'e', pos);
                if (end < 0)
                {
                    return null;
                }

                var n = long.Parse(Encoding.ASCII.GetString(b, pos + 1, end - pos - 1), System.Globalization.CultureInfo.InvariantCulture);
                pos = end + 1;
                return n;
            }

            case 'l':
            {
                pos++;
                var list = new List<object?>();
                while (pos < b.Length && b[pos] != 'e')
                {
                    list.Add(Decode(b, ref pos));
                }

                pos++;
                return list;
            }

            case 'd':
            {
                pos++;
                var dict = new Dictionary<string, object>(StringComparer.Ordinal);
                while (pos < b.Length && b[pos] != 'e')
                {
                    if (Decode(b, ref pos) is not string key)
                    {
                        return null;
                    }

                    var v = Decode(b, ref pos);
                    if (v is not null)
                    {
                        dict[key] = v;
                    }
                }

                pos++;
                return dict;
            }

            default:
            {
                var colon = Array.IndexOf(b, (byte)':', pos);
                if (colon < 0)
                {
                    return null;
                }

                var len = int.Parse(Encoding.ASCII.GetString(b, pos, colon - pos), System.Globalization.CultureInfo.InvariantCulture);
                var s = Encoding.Latin1.GetString(b, colon + 1, len);
                pos = colon + 1 + len;
                return s;
            }
        }
    }
}
