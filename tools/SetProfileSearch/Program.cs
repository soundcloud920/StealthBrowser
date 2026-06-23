using System.Buffers.Binary;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using K4os.Compression.LZ4;

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: SetProfileSearch <profilePath|search.json.mozlz4> [Google|DuckDuckGo|Bing|SearXNG]");
    return 1;
}

var provider = ResolveProvider(args.Length >= 2 ? args[1] : "Google");
var target = args[0];
var searchPath = target.EndsWith("search.json.mozlz4", StringComparison.OrdinalIgnoreCase)
    ? target
    : Path.Combine(target, "search.json.mozlz4");

var root = LoadSearchRoot(searchPath, provider);
ApplyDefaultSearch(root, provider);
WriteMozLz4(searchPath, root.ToJsonString(new JsonSerializerOptions { WriteIndented = false }));
var defaultEngine = root["metaData"]?["default"]?.GetValue<string>() ?? provider.Name;
Console.WriteLine($"OK default={defaultEngine}");
return 0;

static SearchProvider ResolveProvider(string? value)
{
    var requested = string.IsNullOrWhiteSpace(value) ? "Google" : value.Trim();
    if (requested.Equals("Chrome", StringComparison.OrdinalIgnoreCase) ||
        requested.Equals("Google Chrome", StringComparison.OrdinalIgnoreCase))
    {
        requested = "Google";
    }
    else if (requested.Equals("DDG", StringComparison.OrdinalIgnoreCase))
    {
        requested = "DuckDuckGo";
    }
    else if (requested.Equals("SearX", StringComparison.OrdinalIgnoreCase))
    {
        requested = "SearXNG";
    }

    foreach (var provider in GetProviders())
    {
        if (provider.Id.Equals(requested, StringComparison.OrdinalIgnoreCase) ||
            provider.Name.Equals(requested, StringComparison.OrdinalIgnoreCase))
        {
            return provider;
        }
    }

    return GetProviders()[0];
}

static SearchProvider[] GetProviders()
{
    return
    [
        new SearchProvider(
            "Google",
            "Google",
            "https://www.google.com/",
            "https://www.google.com/search",
            [new SearchParam("q", "{searchTerms}")]),
        new SearchProvider(
            "DuckDuckGo",
            "DuckDuckGo",
            "https://duckduckgo.com/",
            "https://duckduckgo.com/",
            [new SearchParam("q", "{searchTerms}")]),
        new SearchProvider(
            "Bing",
            "Bing",
            "https://www.bing.com/",
            "https://www.bing.com/search",
            [new SearchParam("q", "{searchTerms}")]),
        new SearchProvider(
            "SearXNG",
            "SearXNG",
            "https://searx.tiekoetter.com/",
            "https://searx.tiekoetter.com/search",
            [
                new SearchParam("q", "{searchTerms}"),
                new SearchParam("language", "ru-RU")
            ]),
    ];
}

static JsonObject LoadSearchRoot(string searchPath, SearchProvider provider)
{
    if (!File.Exists(searchPath))
    {
        return CreateDefaultRoot(provider);
    }

    var json = DecodeMozLz4(File.ReadAllBytes(searchPath));
    return JsonNode.Parse(json)?.AsObject() ?? CreateDefaultRoot(provider);
}

static JsonObject CreateDefaultRoot(SearchProvider provider)
{
    return new JsonObject
    {
        ["version"] = 12,
        ["engines"] = new JsonArray(),
        ["metaData"] = new JsonObject
        {
            ["useSavedOrder"] = true,
            ["default"] = provider.Name,
            ["defaultPrivate"] = provider.Name,
            ["order"] = new JsonArray(provider.Name)
        }
    };
}

static void ApplyDefaultSearch(JsonObject root, SearchProvider provider)
{
    var engines = root["engines"] as JsonArray ?? new JsonArray();
    root["engines"] = engines;

    JsonObject? selected = null;
    var kept = new JsonArray();
    foreach (var node in engines)
    {
        if (node is not JsonObject engine)
        {
            continue;
        }

        var name = GetEngineName(engine);
        if (string.Equals(name, provider.Name, StringComparison.OrdinalIgnoreCase))
        {
            selected ??= engine.DeepClone().AsObject();
            continue;
        }

        kept.Add(engine.DeepClone());
    }

    selected ??= CreateEngine(provider);
    kept.Insert(0, selected);
    root["engines"] = kept;

    var meta = root["metaData"] as JsonObject ?? new JsonObject();
    meta["useSavedOrder"] = true;
    meta["default"] = provider.Name;
    meta["defaultPrivate"] = provider.Name;

    var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { provider.Name };
    var order = new JsonArray(provider.Name);
    foreach (var node in kept)
    {
        if (node is not JsonObject engine)
        {
            continue;
        }

        var name = GetEngineName(engine);
        if (string.IsNullOrWhiteSpace(name) || !seen.Add(name))
        {
            continue;
        }

        order.Add(name);
    }

    meta["order"] = order;
    root["metaData"] = meta;
}

static string? GetEngineName(JsonObject engine)
{
    return engine["name"]?.GetValue<string>() ??
           engine["_name"]?.GetValue<string>();
}

static JsonObject CreateEngine(SearchProvider provider)
{
    var urlParams = new JsonArray();
    foreach (var param in provider.Params)
    {
        urlParams.Add(new JsonObject
        {
            ["name"] = param.Name,
            ["value"] = param.Value
        });
    }

    return new JsonObject
    {
        ["_name"] = provider.Name,
        ["_isAppProvided"] = false,
        ["_meta"] = new JsonObject
        {
            ["origin"] = "stealth-setup",
            ["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        },
        ["name"] = provider.Name,
        ["isGeneralSearchEngine"] = true,
        ["isDisplayedInSearchBar"] = true,
        ["aliases"] = new JsonArray(),
        ["searchForm"] = provider.SearchForm,
        ["urls"] = new JsonArray
        {
            new JsonObject
            {
                ["params"] = new JsonArray(),
                ["template"] = provider.SearchTemplate
            }
        },
        ["params"] = urlParams
    };
}

static string DecodeMozLz4(byte[] data)
{
    if (data.Length < 12)
    {
        throw new InvalidDataException("search.json.mozlz4 is too small");
    }

    var magic = Encoding.ASCII.GetString(data, 0, 8);
    if (magic != "mozLz40\0")
    {
        throw new InvalidDataException($"Unexpected mozlz4 magic: {magic}");
    }

    var outLen = BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(8, 4));
    var compressed = data.AsSpan(12);
    var output = new byte[outLen];
    var decoded = LZ4Codec.Decode(compressed, output);
    return Encoding.UTF8.GetString(output, 0, decoded);
}

static void WriteMozLz4(string path, string json)
{
    var input = Encoding.UTF8.GetBytes(json);
    var maxLen = LZ4Codec.MaximumOutputSize(input.Length);
    var compressed = new byte[maxLen];
    var encodedLen = LZ4Codec.Encode(input, 0, input.Length, compressed, 0, maxLen);

    using var stream = new MemoryStream(12 + encodedLen);
    stream.Write(Encoding.ASCII.GetBytes("mozLz40\0"));
    stream.Write(BitConverter.GetBytes((uint)input.Length));
    stream.Write(compressed, 0, encodedLen);

    var dir = Path.GetDirectoryName(path);
    if (!string.IsNullOrEmpty(dir))
    {
        Directory.CreateDirectory(dir);
    }

    File.WriteAllBytes(path, stream.ToArray());
}

sealed record SearchProvider(
    string Id,
    string Name,
    string SearchForm,
    string SearchTemplate,
    SearchParam[] Params);

sealed record SearchParam(string Name, string Value);
