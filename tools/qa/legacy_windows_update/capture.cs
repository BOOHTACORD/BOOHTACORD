using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class LegacyCapture {
  [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr handle, out Rect rect);
  public static void Save(int process, string file) {
    LegacyWindow.Foreground(process);
    Rect rect;
    if (!GetWindowRect(LegacyWindow.Handle(process), out rect))
      throw new InvalidOperationException("window_rect_missing");
    int width = rect.Right-rect.Left, height = rect.Bottom-rect.Top;
    if (width < 400 || height < 300 || width > 4096 || height > 2160)
      throw new InvalidOperationException("capture_bound_exceeded");
    using (var bitmap = new Bitmap(width,height)) {
      using (var graphics = Graphics.FromImage(bitmap))
        graphics.CopyFromScreen(rect.Left,rect.Top,0,0,new Size(width,height));
      bitmap.Save(file,ImageFormat.Png);
    }
  }
}
