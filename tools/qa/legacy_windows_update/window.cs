using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Automation;

public static class LegacyWindow {
  delegate bool Visitor(IntPtr window, IntPtr value);
  [DllImport("user32.dll")] static extern bool EnumWindows(Visitor visitor, IntPtr value);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr window, int command);

  public static IntPtr Handle(int process) {
    IntPtr result = IntPtr.Zero;
    EnumWindows(delegate(IntPtr window, IntPtr value) {
      uint owner; GetWindowThreadProcessId(window, out owner);
      if (owner == process && IsWindowVisible(window)) { result = window; return false; }
      return true;
    }, IntPtr.Zero);
    if (result == IntPtr.Zero) throw new InvalidOperationException("owned_window_missing");
    return result;
  }

  public static void Foreground(int process) {
    IntPtr handle = Handle(process);
    ShowWindow(handle, 9); SetForegroundWindow(handle);
    uint owner; GetWindowThreadProcessId(GetForegroundWindow(), out owner);
    if (owner != process) throw new InvalidOperationException("foreground_pid_mismatch");
  }

  public static string[] Names(int process) {
    AutomationElement root = AutomationElement.FromHandle(Handle(process));
    var rows = root.FindAll(TreeScope.Descendants, Condition.TrueCondition);
    if (rows.Count > 4096) throw new InvalidOperationException("uia_bound_exceeded");
    var names = new List<string>();
    foreach (AutomationElement row in rows) {
      try {
        if (!row.Current.IsOffscreen && !String.IsNullOrWhiteSpace(row.Current.Name))
          names.Add(row.Current.Name);
      } catch (ElementNotAvailableException) { }
    }
    return names.ToArray();
  }

  public static bool Contains(string[] names, string text) {
    foreach (string name in names) if (name.Contains(text)) return true;
    return false;
  }

  public static bool Offer(string[] names) { return Contains(names, "Скачать обновление"); }
  public static bool Incorrect(string[] names) {
    return Contains(names, "Эта сборка новее опубликованной") ||
      Contains(names, "Не удалось подтвердить сборку") ||
      Contains(names, "Не удалось определить сборку");
  }

  public static void Details(int process) {
    Foreground(process);
    var root = AutomationElement.FromHandle(Handle(process));
    var button = root.FindFirst(TreeScope.Descendants,
      new PropertyCondition(AutomationElement.NameProperty, "Что нового"));
    if (button == null) throw new InvalidOperationException("details_button_missing");
    object pattern;
    if (!button.TryGetCurrentPattern(InvokePattern.Pattern, out pattern))
      throw new InvalidOperationException("details_invoke_missing");
    ((InvokePattern)pattern).Invoke();
  }
}
