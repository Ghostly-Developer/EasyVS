// Small launcher so the app can be shared as one .exe with its own icon.
// The PowerShell setup script (OpenWithVSCode.cmd) is embedded as a resource. On start the
// launcher writes it to %TEMP% and runs it with Windows PowerShell, passing any arguments through.
// Built by build.ps1 with the C# compiler that ships with Windows (.NET Framework 4).
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

static class Launcher
{
    const string AppName = "Open with VS Code";

    [STAThread]
    static int Main(string[] args)
    {
        try
        {
            string script;
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("OpenWithVSCode.ps1"))
            using (StreamReader r = new StreamReader(s))
            {
                script = r.ReadToEnd();
            }

            string path = Path.Combine(Path.GetTempPath(), "OpenWithVSCode-setup.ps1");
            File.WriteAllText(path, script, new UTF8Encoding(false));

            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                                             @"WindowsPowerShell\v1.0\powershell.exe");
            StringBuilder arguments = new StringBuilder("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ");
            arguments.Append(Quote(path));
            foreach (string a in args) arguments.Append(' ').Append(Quote(a));

            ProcessStartInfo psi = new ProcessStartInfo(powershell, arguments.ToString());
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi))
            {
                p.WaitForExit();
                return p.ExitCode;
            }
        }
        catch (Exception e)
        {
            MessageBox.Show("Could not start the setup:\n\n" + e.Message, AppName,
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    // Quotes one argument the way Windows programs (including PowerShell) split command lines.
    static string Quote(string a)
    {
        if (a.Length > 0 && a.IndexOfAny(new[] { ' ', '\t', '"' }) < 0) return a;
        StringBuilder sb = new StringBuilder("\"");
        int backslashes = 0;
        foreach (char c in a)
        {
            if (c == '\\') { backslashes++; continue; }
            if (c == '"') { sb.Append('\\', backslashes * 2 + 1); }
            else { sb.Append('\\', backslashes); }
            backslashes = 0;
            sb.Append(c);
        }
        sb.Append('\\', backslashes * 2);
        sb.Append('"');
        return sb.ToString();
    }
}
