using System.Globalization;
using Microsoft.Data.Sqlite;

namespace StealthBrowser.Tools;

internal static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: SetProfileZoom <content-prefs.sqlite> <zoom>");
            return 1;
        }

        var dbPath = args[0];
        var zoom = double.Parse(args[1], CultureInfo.InvariantCulture);
        var value = zoom.ToString("G", CultureInfo.InvariantCulture);

        using var connection = new SqliteConnection($"Data Source={dbPath}");
        connection.Open();

        long settingId;
        using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id FROM settings WHERE name = 'browser.content.full-zoom'";
            var existing = command.ExecuteScalar();
            if (existing is null)
            {
                using var insert = connection.CreateCommand();
                insert.CommandText = "INSERT INTO settings (name) VALUES ('browser.content.full-zoom')";
                insert.ExecuteNonQuery();
                using var idCommand = connection.CreateCommand();
                idCommand.CommandText = "SELECT last_insert_rowid()";
                settingId = Convert.ToInt64(idCommand.ExecuteScalar(), CultureInfo.InvariantCulture);
            }
            else
            {
                settingId = Convert.ToInt64(existing, CultureInfo.InvariantCulture);
            }
        }

        using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id FROM prefs WHERE settingID = $settingId AND groupID IS NULL";
            command.Parameters.AddWithValue("$settingId", settingId);
            var existing = command.ExecuteScalar();

            if (existing is null)
            {
                command.CommandText =
                    "INSERT INTO prefs (groupID, settingID, value, timestamp) VALUES (NULL, $settingId, $value, 0)";
                command.Parameters.Clear();
                command.Parameters.AddWithValue("$settingId", settingId);
                command.Parameters.AddWithValue("$value", value);
            }
            else
            {
                command.CommandText = "UPDATE prefs SET value = $value WHERE id = $id";
                command.Parameters.Clear();
                command.Parameters.AddWithValue("$value", value);
                command.Parameters.AddWithValue("$id", Convert.ToInt64(existing, CultureInfo.InvariantCulture));
            }

            command.ExecuteNonQuery();
        }

        return 0;
    }
}
