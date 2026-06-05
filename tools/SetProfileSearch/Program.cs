using System.Buffers.Binary;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using K4os.Compression.LZ4;

const string EngineName = "SearXNG";
const string SearchTemplate = "https://searx.tiekoetter.com/search";
const string SearchForm = "https://searx.tiekoetter.com/";

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: SetProfileSearch <profilePath|search.json.mozlz4>");
    return 1;
}

var target = args[0];
var searchPath = target.EndsWith("search.json.mozlz4", StringComparison.OrdinalIgnoreCase)
    ? target
    : Path.Combine(target, "search.json.mozlz4");

var root = LoadSearchRoot(searchPath);
ApplySearxngDefault(root);
WriteMozLz4(searchPath, root.ToJsonString(new JsonSerializerOptions { WriteIndented = false }));
var defaultEngine = root["metaData"]?["default"]?.GetValue<string>() ?? EngineName;
Console.WriteLine($"OK default={defaultEngine}");
return 0;

static JsonObject LoadSearchRoot(string searchPath)
{
    if (!File.Exists(searchPath))
    {
        return CreateDefaultRoot();
    }

    var json = DecodeMozLz4(File.ReadAllBytes(searchPath));
    return JsonNode.Parse(json)?.AsObject() ?? CreateDefaultRoot();
}

static JsonObject CreateDefaultRoot()
{
    return new JsonObject
    {
        ["version"] = 12,
        ["engines"] = new JsonArray(),
        ["metaData"] = new JsonObject
        {
            ["useSavedOrder"] = true,
            ["default"] = EngineName,
            ["defaultPrivate"] = EngineName,
            ["order"] = new JsonArray(EngineName)
        }
    };
}

static void ApplySearxngDefault(JsonObject root)
{
    var engines = root["engines"] as JsonArray ?? new JsonArray();
    root["engines"] = engines;

    var kept = new JsonArray();
    foreach (var node in engines)
    {
        if (node is not JsonObject engine)
        {
            continue;
        }

        var name = engine["name"]?.GetValue<string>();
        if (string.Equals(name, EngineName, StringComparison.Ordinal))
        {
            continue;
        }

        kept.Add(engine.DeepClone());
    }

    kept.Insert(0, CreateSearxngEngine());
    root["engines"] = kept;

    var meta = root["metaData"] as JsonObject ?? new JsonObject();
    meta["useSavedOrder"] = true;
    meta["default"] = EngineName;
    meta["defaultPrivate"] = EngineName;

    var order = new JsonArray { EngineName };
    foreach (var node in kept)
    {
        if (node is not JsonObject engine)
        {
            continue;
        }

        var name = engine["name"]?.GetValue<string>();
        if (string.IsNullOrWhiteSpace(name) || string.Equals(name, EngineName, StringComparison.Ordinal))
        {
            continue;
        }

        order.Add(name);
    }

    meta["order"] = order;
    root["metaData"] = meta;
}

static JsonObject CreateSearxngEngine()
{
    return new JsonObject
    {
        ["_name"] = EngineName,
        ["_isAppProvided"] = false,
        ["_meta"] = new JsonObject
        {
            ["origin"] = "stealth-setup",
            ["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        },
        ["name"] = EngineName,
        ["isGeneralSearchEngine"] = true,
        ["isDisplayedInSearchBar"] = true,
        ["aliases"] = new JsonArray(),
        ["searchForm"] = SearchForm,
        ["urls"] = new JsonArray
        {
            new JsonObject
            {
                ["params"] = new JsonArray(),
                ["template"] = SearchTemplate
            }
        },
        ["params"] = new JsonArray
        {
            new JsonObject
            {
                ["name"] = "q",
                ["value"] = "{searchTerms}"
            },
            new JsonObject
            {
                ["name"] = "language",
                ["value"] = "ru-RU"
            }
        }
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
