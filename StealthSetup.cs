using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace StealthBrowser
{
    internal static class SetupProgram
    {
        private const string PayloadResource = "StealthBrowser.SetupPayload.zip";
        private const string SetupAppUserModelId = "StealthBrowser.Setup";

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

        [STAThread]
        private static int Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            TrySetSetupAppUserModelId();

            bool silent = HasArg(args, "/install") || HasArg(args, "-install");
            try
            {
                string installDir = ExtractPayload(null);
                if (silent)
                    return RunInstallScript(installDir, true, BuildInstallScriptArguments(args));

                return RunSetupGui(installDir);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    ex.Message,
                    "StealthBrowser",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 1;
            }
        }

        private static void TrySetSetupAppUserModelId()
        {
            try { SetCurrentProcessExplicitAppUserModelID(SetupAppUserModelId); }
            catch { }
        }

        private static bool HasArg(string[] args, string name)
        {
            if (args == null) return false;
            foreach (string arg in args)
            {
                if (string.Equals(arg, name, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        internal static string ExtractPayload(Action<int> reportProgress)
        {
            string root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "StealthBrowser",
                "SetupPackage");

            if (Directory.Exists(root))
            {
                try { Directory.Delete(root, true); }
                catch { }
            }
            Directory.CreateDirectory(root);

            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResource))
            {
                if (stream == null)
                    throw new InvalidOperationException("Installer payload is missing.");
                using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
                {
                    int total = archive.Entries.Count;
                    int done = 0;
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        string dest = Path.Combine(root, entry.FullName);
                        if (string.IsNullOrEmpty(entry.Name))
                        {
                            Directory.CreateDirectory(dest);
                        }
                        else
                        {
                            string parent = Path.GetDirectoryName(dest);
                            if (!string.IsNullOrEmpty(parent))
                                Directory.CreateDirectory(parent);
                            entry.ExtractToFile(dest, true);
                        }
                        done++;
                        if (reportProgress != null && total > 0)
                            reportProgress(Math.Min(100, (done * 100) / total));
                    }
                }
            }

            if (reportProgress != null) reportProgress(100);
            return root;
        }

        internal static int RunSetupGui(string installDir)
        {
            string setup = Path.Combine(installDir, "Setup.ps1");
            if (!File.Exists(setup))
                throw new FileNotFoundException("Setup.ps1 not found after extraction.", setup);

            return RunPowerShellFile(installDir, setup, hidden: false);
        }

        internal static int RunInstallScript(string installDir, bool hidden)
        {
            return RunInstallScript(installDir, hidden, string.Empty);
        }

        internal static int RunInstallScript(string installDir, bool hidden, string scriptArguments)
        {
            string script = Path.Combine(installDir, "Install-Stealth.ps1");
            if (!File.Exists(script))
                throw new FileNotFoundException("Install-Stealth.ps1 not found after extraction.", script);

            return RunPowerShellFile(installDir, script, hidden, scriptArguments);
        }

        private static int RunPowerShellFile(string installDir, string scriptPath, bool hidden)
        {
            return RunPowerShellFile(installDir, scriptPath, hidden, string.Empty);
        }

        private static int RunPowerShellFile(string installDir, string scriptPath, bool hidden, string scriptArguments)
        {
            string windowStyle = hidden ? "Hidden" : "Normal";
            string arguments = string.Format(
                "-NoProfile -ExecutionPolicy Bypass -WindowStyle {0} -File \"{1}\"",
                windowStyle,
                scriptPath);
            if (!string.IsNullOrWhiteSpace(scriptArguments))
                arguments += " " + scriptArguments;

            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = arguments,
                WorkingDirectory = installDir,
                UseShellExecute = false,
            };

            if (hidden)
                psi.CreateNoWindow = true;

            using (Process proc = Process.Start(psi))
            {
                if (proc == null)
                    throw new InvalidOperationException("Failed to start PowerShell.");

                proc.WaitForExit();
                if (proc.ExitCode != 0)
                    throw new InvalidOperationException(
                        string.Format("Setup script failed with exit code {0}.", proc.ExitCode));

                return proc.ExitCode;
            }
        }

        private static string BuildInstallScriptArguments(string[] args)
        {
            bool profileOnly = false;
            string searchEngine = null;

            if (args != null)
            {
                for (int i = 0; i < args.Length; i++)
                {
                    string arg = args[i] ?? string.Empty;
                    if (string.Equals(arg, "/install", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(arg, "-install", StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    if (string.Equals(arg, "/profileonly", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(arg, "-profileonly", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(arg, "-ProfileOnly", StringComparison.OrdinalIgnoreCase))
                    {
                        profileOnly = true;
                        continue;
                    }

                    if (TryReadValueArg(arg, "/search=", ref searchEngine) ||
                        TryReadValueArg(arg, "/searchengine=", ref searchEngine) ||
                        TryReadValueArg(arg, "--search=", ref searchEngine) ||
                        TryReadValueArg(arg, "--searchengine=", ref searchEngine) ||
                        TryReadValueArg(arg, "-SearchEngine=", ref searchEngine))
                    {
                        continue;
                    }

                    if ((string.Equals(arg, "/search", StringComparison.OrdinalIgnoreCase) ||
                         string.Equals(arg, "/searchengine", StringComparison.OrdinalIgnoreCase) ||
                         string.Equals(arg, "-SearchEngine", StringComparison.OrdinalIgnoreCase)) &&
                        i + 1 < args.Length)
                    {
                        searchEngine = args[++i];
                    }
                }
            }

            string result = string.Empty;
            if (profileOnly)
                result += " -ProfileOnly";
            if (!string.IsNullOrWhiteSpace(searchEngine))
                result += " -SearchEngine " + QuotePowerShellArgument(searchEngine);

            return result.Trim();
        }

        private static bool TryReadValueArg(string arg, string prefix, ref string value)
        {
            if (!arg.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                return false;

            value = arg.Substring(prefix.Length);
            return true;
        }

        private static string QuotePowerShellArgument(string value)
        {
            if (value == null)
                return "''";
            return "'" + value.Replace("'", "''") + "'";
        }
    }
}
