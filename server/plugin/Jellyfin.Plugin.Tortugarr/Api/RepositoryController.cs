using System.IO.Compression;
using System.Net.Mime;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Jellyfin.Plugin.Tortugarr.Api;

/// <summary>
/// Spec 3.13: a plugin catalog served by the plugin itself, so Jellyfin's plugin page finds
/// Tortugarr in a repository (without one it shows "error fetching repository details").
/// It lists only the installed version and serves that version's files as the package zip.
/// No login: it holds nothing but the plugin itself - never configuration or keys.
/// </summary>
[ApiController]
[AllowAnonymous]
[Route("Tortugarr/v1/Repository")]
public class RepositoryController : ControllerBase
{
    private static readonly object Gate = new();
    private static byte[]? _zip;

    private static string PluginDir =>
        Path.GetDirectoryName(Plugin.Instance?.AssemblyFilePath ?? typeof(Plugin).Assembly.Location) ?? string.Empty;

    private static string Version => Plugin.Instance?.Version.ToString() ?? "0.0.0.0";

    /// <summary>The installed version's files (the DLLs and meta.json), built once per start.</summary>
    internal static byte[] Zip()
    {
        lock (Gate)
        {
            if (_zip is not null)
            {
                return _zip;
            }

            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, true))
            {
                foreach (var file in Directory.GetFiles(PluginDir).Where(f => f.EndsWith(".dll", StringComparison.OrdinalIgnoreCase)
                             || Path.GetFileName(f) is "meta.json" or "logo.png").OrderBy(f => f, StringComparer.Ordinal))
                {
                    var entry = zip.CreateEntry(Path.GetFileName(file), CompressionLevel.Optimal);
                    entry.LastWriteTime = new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);
                    using var to = entry.Open();
                    using var from = System.IO.File.OpenRead(file);
                    from.CopyTo(to);
                }
            }

            _zip = ms.ToArray();
            return _zip;
        }
    }

    private static JsonNode? Meta()
    {
        try
        {
            return JsonNode.Parse(System.IO.File.ReadAllText(Path.Combine(PluginDir, "meta.json")));
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    [HttpGet("manifest.json")]
    [Produces(MediaTypeNames.Application.Json)]
    public IActionResult Manifest()
    {
        var meta = Meta();
        var zipName = $"Tortugarr_{Version}.zip";
        var root = $"{Request.Scheme}://{Request.Host}{Request.PathBase}/Tortugarr/v1/Repository";
        var source = $"{root}/{zipName}";
        var manifest = new[]
        {
            new
            {
                guid = "19f30fb1-bb78-444b-a75e-2997883b215c",
                name = "Tortugarr",
                description = (string?)meta?["description"] ?? "Server side of the Tortugarr app.",
                overview = (string?)meta?["overview"] ?? "Download Now and subtitles for the Tortugarr app, without keys in the app.",
                owner = "Tortugarr",
                category = "General",
                imageUrl = $"{root}/logo.png",
                versions = new[]
                {
                    new
                    {
                        version = Version,
                        changelog = "Installed by the Tortugarr installer.",
                        targetAbi = (string?)meta?["targetAbi"] ?? "12.0.0.0",
                        sourceUrl = source,
                        checksum = Convert.ToHexString(MD5.HashData(Zip())).ToLowerInvariant(),
                        timestamp = (string?)meta?["timestamp"] ?? "2026-10-06T00:00:00Z",
                    },
                },
            },
        };
        return new ContentResult
        {
            ContentType = "application/json; charset=utf-8",
            Content = JsonSerializer.Serialize(manifest),
        };
    }

    [HttpGet("logo.png")]
    public IActionResult Logo()
    {
        var path = Path.Combine(PluginDir, "logo.png");
        return System.IO.File.Exists(path) ? PhysicalFile(path, "image/png") : NotFound();
    }

    [HttpGet("{zipName}")]
    public IActionResult Package([FromRoute] string zipName) =>
        zipName == $"Tortugarr_{Version}.zip" ? File(Zip(), "application/zip", zipName) : NotFound();
}
