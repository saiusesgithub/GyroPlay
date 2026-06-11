using System;
using System.IO;
using System.Runtime.InteropServices;
using Windows.ApplicationModel.DataTransfer;

namespace GyroPlay.Desktop.Services;

public sealed class TrayService : IDisposable
{
    private const int TrayMessage = 0x0400 + 42;
    private const int WmDestroy = 0x0002;
    private const int WmRButtonUp = 0x0205;
    private const int WmLButtonDblClk = 0x0203;
    private const int NidAdd = 0x00000000;
    private const int NidDelete = 0x00000002;
    private const int NifMessage = 0x00000001;
    private const int NifIcon = 0x00000002;
    private const int NifTip = 0x00000004;
    private const int NifInfo = 0x00000010;
    private const uint MfString = 0x00000000;
    private const uint MfSeparator = 0x00000800;
    private const uint TpmReturNcmd = 0x0100;
    private const int ImageIcon = 1;
    private const int LrLoadFromFile = 0x00000010;
    private const int LrDefaultSize = 0x00000040;
    private const int IdOpen = 1001;
    private const int IdStart = 1002;
    private const int IdStop = 1003;
    private const int IdCopyIp = 1004;
    private const int IdExit = 1005;

    private readonly WndProc _wndProc;
    private nint _windowHandle;
    private nint _trayIconHandle;
    private AppPaths? _paths;
    private bool _created;
    private EngineService _engine = new();

    public event Action? OpenRequested;
    public event Action? ExitRequested;

    public TrayService()
    {
        _wndProc = WindowProcedure;
    }

    public void Initialize(AppPaths paths, EngineService engine, NotificationService notifications)
    {
        _paths = paths;
        _engine = engine;
        notifications.AttachTray(this);
    }

    public void EnsureCreated()
    {
        if (_created)
        {
            return;
        }

        CreateMessageWindow();
        var data = CreateNotifyIconData();
        Shell_NotifyIcon(NidAdd, ref data);
        _created = true;
    }

    public void ShowNotification(string title, string message)
    {
        EnsureCreated();
        var data = CreateNotifyIconData();
        data.uFlags = NifInfo;
        data.szInfoTitle = title;
        data.szInfo = message;
        Shell_NotifyIcon(0x00000001, ref data);
    }

    private NotifyIconData CreateNotifyIconData()
    {
        return new NotifyIconData
        {
            cbSize = Marshal.SizeOf<NotifyIconData>(),
            hWnd = _windowHandle,
            uID = 1,
            uFlags = NifMessage | NifIcon | NifTip,
            uCallbackMessage = TrayMessage,
            hIcon = GetTrayIconHandle(),
            szTip = "GyroPlay",
        };
    }

    private nint GetTrayIconHandle()
    {
        if (_trayIconHandle != nint.Zero)
        {
            return _trayIconHandle;
        }

        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "GyroPlay.ico");
        if (File.Exists(iconPath))
        {
            _trayIconHandle = LoadImage(nint.Zero, iconPath, ImageIcon, 16, 16, LrLoadFromFile);
        }

        if (_trayIconHandle == nint.Zero)
        {
            _trayIconHandle = LoadIcon(nint.Zero, new IntPtr(32512));
        }

        return _trayIconHandle;
    }

    private void CreateMessageWindow()
    {
        var className = "GyroPlayTrayWindow";
        var wc = new WindowClass
        {
            lpfnWndProc = _wndProc,
            lpszClassName = className,
        };
        RegisterClass(ref wc);
        _windowHandle = CreateWindowEx(0, className, className, 0, 0, 0, 0, 0, nint.Zero, nint.Zero, nint.Zero, nint.Zero);
    }

    private nint WindowProcedure(nint hWnd, uint msg, nint wParam, nint lParam)
    {
        if (msg == TrayMessage)
        {
            var mouseMessage = lParam.ToInt32();
            if (mouseMessage == WmLButtonDblClk)
            {
                OpenRequested?.Invoke();
            }
            else if (mouseMessage == WmRButtonUp)
            {
                ShowMenu();
            }
        }
        else if (msg == WmDestroy)
        {
            var data = CreateNotifyIconData();
            Shell_NotifyIcon(NidDelete, ref data);
        }

        return DefWindowProc(hWnd, msg, wParam, lParam);
    }

    private void ShowMenu()
    {
        var menu = CreatePopupMenu();
        AppendMenu(menu, MfString, IdOpen, "Open GyroPlay");
        AppendMenu(menu, MfString, IdStart, "Start Engine");
        AppendMenu(menu, MfString, IdStop, "Stop Engine");
        AppendMenu(menu, MfString, IdCopyIp, "Copy PC IP");
        AppendMenu(menu, MfSeparator, 0, string.Empty);
        AppendMenu(menu, MfString, IdExit, "Exit");
        GetCursorPos(out var point);
        SetForegroundWindow(_windowHandle);
        var command = TrackPopupMenu(menu, TpmReturNcmd, point.X, point.Y, 0, _windowHandle, nint.Zero);
        DestroyMenu(menu);

        switch (command)
        {
            case IdOpen:
                OpenRequested?.Invoke();
                break;
            case IdStart:
                _engine.Start();
                break;
            case IdStop:
                _engine.Stop();
                break;
            case IdCopyIp:
                CopyIp();
                break;
            case IdExit:
                ExitRequested?.Invoke();
                break;
        }
    }

    private static void CopyIp()
    {
        var package = new DataPackage();
        package.SetText(HealthCheckService.GetLocalIpv4Address());
        Clipboard.SetContent(package);
    }

    public void Dispose()
    {
        if (!_created)
        {
            return;
        }

        var data = CreateNotifyIconData();
        Shell_NotifyIcon(NidDelete, ref data);
        if (_windowHandle != nint.Zero)
        {
            DestroyWindow(_windowHandle);
            _windowHandle = nint.Zero;
        }
        if (_trayIconHandle != nint.Zero)
        {
            DestroyIcon(_trayIconHandle);
            _trayIconHandle = nint.Zero;
        }
        _created = false;
    }

    private delegate nint WndProc(nint hWnd, uint msg, nint wParam, nint lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WindowClass
    {
        public uint style;
        public WndProc lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public nint hInstance;
        public nint hIcon;
        public nint hCursor;
        public nint hbrBackground;
        public string? lpszMenuName;
        public string lpszClassName;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NotifyIconData
    {
        public int cbSize;
        public nint hWnd;
        public int uID;
        public int uFlags;
        public int uCallbackMessage;
        public nint hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
        public int dwState;
        public int dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string szInfo;
        public int uTimeoutOrVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string szInfoTitle;
        public int dwInfoFlags;
        public Guid guidItem;
        public nint hBalloonIcon;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern ushort RegisterClass(ref WindowClass lpWndClass);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern nint CreateWindowEx(int exStyle, string className, string windowName, int style, int x, int y, int width, int height, nint parent, nint menu, nint instance, nint param);

    [DllImport("user32.dll")]
    private static extern nint DefWindowProc(nint hWnd, uint msg, nint wParam, nint lParam);

    [DllImport("user32.dll")]
    private static extern bool DestroyWindow(nint hWnd);

    [DllImport("user32.dll")]
    private static extern nint LoadIcon(nint hInstance, nint lpIconName);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern nint LoadImage(nint hInst, string name, int type, int cx, int cy, int fuLoad);

    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(nint hIcon);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern bool Shell_NotifyIcon(int dwMessage, ref NotifyIconData lpData);

    [DllImport("user32.dll")]
    private static extern nint CreatePopupMenu();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool AppendMenu(nint hMenu, uint uFlags, int uIDNewItem, string lpNewItem);

    [DllImport("user32.dll")]
    private static extern bool DestroyMenu(nint hMenu);

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out Point lpPoint);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(nint hWnd);

    [DllImport("user32.dll")]
    private static extern int TrackPopupMenu(nint hMenu, uint uFlags, int x, int y, int nReserved, nint hWnd, nint prcRect);
}
