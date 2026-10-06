using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace CodexDynamicSkin {
  [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IApplicationActivationManager {
    [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
      [MarshalAs(UnmanagedType.LPWStr)] string arguments, uint options, out uint processId);
  }
  [ComImport, Guid("45ba127d-10a8-46ea-8ab7-56ea9078943c")]
  class ApplicationActivationManager {}

  static class Program {
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 65536 };
    static string Value(Dictionary<string, object> state, string name) {
      object value; return state.TryGetValue(name, out value) && value != null ? Convert.ToString(value) : "";
    }
    static int Number(Dictionary<string, object> state, string name) {
      int value; return Int32.TryParse(Value(state, name), out value) ? value : 0;
    }
    static bool SamePath(string left, string right) {
      try { return String.Equals(Path.GetFullPath(left).TrimEnd('\\'), Path.GetFullPath(right).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase); }
      catch { return false; }
    }
    static bool SameStart(Process process, string expected) {
      DateTime saved;
      return DateTime.TryParse(expected, null, System.Globalization.DateTimeStyles.RoundtripKind, out saved) &&
        process.StartTime.ToUniversalTime().Ticks == saved.ToUniversalTime().Ticks;
    }
    static bool ManagedProcess(Dictionary<string, object> state, string pidName, string startName) {
      int pid = Number(state, pidName); if (pid <= 0) return false;
      try {
        using (Process process = Process.GetProcessById(pid)) {
          return SamePath(process.MainModule.FileName, Value(state, "nodePath")) && SameStart(process, Value(state, startName));
        }
      } catch { return false; }
    }
    static string EndpointBrowserId(int port) {
      var request = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:" + port + "/json/version");
      request.Proxy = null; request.AllowAutoRedirect = false; request.Timeout = 600; request.ReadWriteTimeout = 600;
      using (var response = request.GetResponse()) using (var reader = new StreamReader(response.GetResponseStream())) {
        var value = Json.Deserialize<Dictionary<string, object>>(reader.ReadToEnd());
        string socket = Convert.ToString(value["webSocketDebuggerUrl"]);
        var match = Regex.Match(socket, "^ws://127\\.0\\.0\\.1:" + port + "/devtools/browser/(?<id>[A-Za-z0-9._-]{1,200})$");
        return match.Success ? match.Groups["id"].Value : "";
      }
    }
    static void FullStart(string root) {
      string script = Path.Combine(root, "engine", "scripts", "start-dream-skin.ps1");
      var info = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe"),
        "-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File \"" + script.Replace("\"", "\\\"") + "\" -PromptRestart");
      info.UseShellExecute = false; info.CreateNoWindow = true; info.WindowStyle = ProcessWindowStyle.Hidden;
      Process.Start(info);
    }
    static bool QuickStart(string root) {
      string statePath = Path.Combine(root, "state.json");
      var file = new FileInfo(statePath); if (!file.Exists || file.Length < 2 || file.Length > 65536) return false;
      var state = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(statePath));
      if (Value(state, "schemaVersion") != "3" || !String.Equals(Value(state, "platform"), "windows", StringComparison.OrdinalIgnoreCase)) return false;
      int port = Number(state, "port"); if (port < 1024 || port > 65535) return false;
      string browserId = EndpointBrowserId(port); if (browserId == "" || browserId != Value(state, "browserId")) return false;
      string family = Value(state, "codexPackageFamilyName"); if (!Regex.IsMatch(family, "^OpenAI\\.Codex_[A-Za-z0-9]+$")) return false;
      if (!SamePath(Value(state, "profilePath"), Path.Combine(root, "cdp-profile")) ||
          !SamePath(Value(state, "nodePath"), Path.Combine(root, "engine", "runtime", "node", "node.exe")) ||
          !SamePath(Value(state, "injectorPath"), Path.Combine(root, "engine", "scripts", "injector.mjs")) ||
          !ManagedProcess(state, "injectorPid", "injectorStartedAt")) return false;
      if (Number(state, "videoPid") > 0 && (!SamePath(Value(state, "videoScript"), Path.Combine(root, "engine", "scripts", "video-server.mjs")) ||
          !ManagedProcess(state, "videoPid", "videoStartedAt"))) return false;
      var manager = (IApplicationActivationManager)new ApplicationActivationManager();
      try {
        uint pid; string args = "--remote-debugging-address=127.0.0.1 --remote-debugging-port=" + port +
          " --user-data-dir=\"" + Value(state, "profilePath").Replace("\"", "\\\"") + "\"";
        Marshal.ThrowExceptionForHR(manager.ActivateApplication(family + "!App", args, 0, out pid));
        return pid > 0;
      } finally { if (Marshal.IsComObject(manager)) Marshal.FinalReleaseComObject(manager); }
    }
    [STAThread]
    static void Main() {
      string engine = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
      string root = Directory.GetParent(engine).Parent.FullName;
      try { if (QuickStart(root)) return; } catch {}
      try { FullStart(root); } catch {}
    }
  }
}
