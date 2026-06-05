using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace StealthBrowser
{
    internal static class Program
    {
        private const int UpdateCheckTimeoutMs = 4000;
        private const int UpdateCheckIntervalHours = 24;

        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            try
            {
                Run();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "StealthBrowser", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static void Run()
        {
            string appDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "StealthBrowser");
            string configPath = Path.Combine(appDir, "config.json");

            if (!File.Exists(configPath))
            {
                MessageBox.Show(
                    "Stealth не настроен. Запустите установщик из папки StealthBrowser.",
                    "StealthBrowser",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            string json = File.ReadAllText(configPath);
            string profile = ReadJsonString(json, "profilePath");
            string engine = ReadJsonString(json, "stealthExe");
            string setupVersion = ReadJsonString(json, "setupVersion");
            string githubRepo = ReadJsonString(json, "githubRepo");
            string dismissed = ReadJsonString(json, "dismissedVersion");
            string product = ReadJsonString(json, "productName");
            if (string.IsNullOrEmpty(product)) product = "StealthBrowser";
            if (string.IsNullOrEmpty(githubRepo)) githubRepo = "soundcloud920/StealthBrowser";

            if (string.IsNullOrEmpty(profile) || string.IsNullOrEmpty(engine) || !File.Exists(engine))
            {
                MessageBox.Show(
                    "Не найден профиль или движок Stealth. Переустановите через Setup.",
                    "StealthBrowser",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            StartBrowser(engine, profile);
            TryPromptUpdate(configPath, appDir, product, setupVersion, githubRepo, dismissed, json);
        }

        private static void StartBrowser(string engine, string profile)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = engine,
                Arguments = "-no-remote -profile \"" + profile + "\"",
                UseShellExecute = true
            });
        }

        private static void TryPromptUpdate(
            string configPath,
            string appDir,
            string product,
            string current,
            string repo,
            string dismissed,
            string json)
        {
            if (string.IsNullOrEmpty(current)) return;

            string latest = ResolveLatestVersion(configPath, repo, json);
            if (string.IsNullOrEmpty(latest)) return;
            if (CompareVersion(latest, current) <= 0) return;
            if (!string.IsNullOrEmpty(dismissed) && CompareVersion(latest, dismissed) <= 0) return;

            DialogResult answer = MessageBox.Show(
                "Доступно обновление " + product + ".\r\n\r\n" +
                "Установлено: v" + current + "\r\n" +
                "На GitHub:    v" + latest + "\r\n\r\n" +
                "Да — обновить сейчас (откроется окно установки)\r\n" +
                "Нет — запустить без обновления\r\n" +
                "Отмена — не напоминать про v" + latest,
                product + " — обновление",
                MessageBoxButtons.YesNoCancel,
                MessageBoxIcon.Information);

            if (answer == DialogResult.Cancel)
            {
                WriteJsonStringField(configPath, "dismissedVersion", latest);
                return;
            }

            if (answer == DialogResult.Yes)
            {
                string ps1 = Path.Combine(appDir, "Stealth-ApplyUpdate.ps1");
                if (!File.Exists(ps1)) return;

                Process.Start(new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File \"" + ps1 + "\"",
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Normal
                });
            }
        }

        private static string ResolveLatestVersion(string configPath, string repo, string json)
        {
            string cachedLatest = ReadJsonString(json, "lastUpdateCheckLatest");
            string cachedUtc = ReadJsonString(json, "lastUpdateCheckUtc");

            if (IsUpdateCacheFresh(cachedUtc) && !string.IsNullOrEmpty(cachedLatest))
            {
                return cachedLatest;
            }

            try
            {
                string latest = FetchLatestVersion(repo, UpdateCheckTimeoutMs);
                if (!string.IsNullOrEmpty(latest))
                {
                    WriteUpdateCheckCache(configPath, latest);
                }
                return latest;
            }
            catch
            {
                return cachedLatest;
            }
        }

        private static bool IsUpdateCacheFresh(string cachedUtc)
        {
            if (string.IsNullOrEmpty(cachedUtc)) return false;

            DateTime checkedAt;
            if (!DateTime.TryParse(
                cachedUtc,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out checkedAt))
            {
                return false;
            }

            return (DateTime.UtcNow - checkedAt).TotalHours < UpdateCheckIntervalHours;
        }

        private static void WriteUpdateCheckCache(string configPath, string latest)
        {
            string utc = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
            WriteJsonStringField(configPath, "lastUpdateCheckUtc", utc);
            WriteJsonStringField(configPath, "lastUpdateCheckLatest", latest);
        }

        private static void WriteJsonStringField(string configPath, string key, string value)
        {
            string json = File.ReadAllText(configPath);
            string pattern = "\"" + Regex.Escape(key) + "\"\\s*:\\s*\"[^\"]*\"";
            string replacement = "\"" + key + "\": \"" + EscapeJson(value) + "\"";

            if (Regex.IsMatch(json, pattern))
            {
                json = Regex.Replace(json, pattern, replacement);
            }
            else
            {
                json = json.TrimEnd().TrimEnd('}') + ",\r\n    \"" + key + "\": \"" + EscapeJson(value) + "\"\r\n}";
            }

            File.WriteAllText(configPath, json);
        }

        private static string EscapeJson(string value)
        {
            return (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private static string FetchLatestVersion(string repo, int timeoutMs)
        {
            string url = "https://api.github.com/repos/" + repo + "/releases/latest";
            var request = (HttpWebRequest)WebRequest.Create(url);
            request.Method = "GET";
            request.Timeout = timeoutMs;
            request.ReadWriteTimeout = timeoutMs;
            request.UserAgent = "StealthBrowser-Launcher";

            using (var response = (HttpWebResponse)request.GetResponse())
            using (var reader = new StreamReader(response.GetResponseStream()))
            {
                string body = reader.ReadToEnd();
                Match tag = Regex.Match(body, "\"tag_name\"\\s*:\\s*\"([^\"]+)\"");
                if (!tag.Success) return null;
                return tag.Groups[1].Value.TrimStart('v', 'V');
            }
        }

        private static string NormalizeVersion(string value)
        {
            if (string.IsNullOrEmpty(value)) return "0";
            string v = value.Trim().TrimStart('v', 'V');
            int dash = v.IndexOf('-');
            if (dash >= 0) v = v.Substring(0, dash);
            int plus = v.IndexOf('+');
            if (plus >= 0) v = v.Substring(0, plus);
            return v;
        }

        private static int CompareVersion(string a, string b)
        {
            string[] pa = NormalizeVersion(a).Split('.');
            string[] pb = NormalizeVersion(b).Split('.');
            int len = Math.Max(pa.Length, pb.Length);
            for (int i = 0; i < len; i++)
            {
                int va = 0;
                int vb = 0;
                if (i < pa.Length) int.TryParse(pa[i], out va);
                if (i < pb.Length) int.TryParse(pb[i], out vb);
                if (va != vb) return va.CompareTo(vb);
            }
            return 0;
        }

        private static string ReadJsonString(string json, string key)
        {
            Match m = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*\"([^\"]*)\"");
            return m.Success ? m.Groups[1].Value.Replace("\\\\", "\\") : null;
        }
    }
}
