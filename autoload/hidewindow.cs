using Godot;
using System;
using System.Runtime.InteropServices;

public partial class hidewindow : Node
{
	// Windows API常量和函数声明
	private const int GWL_EXSTYLE = -20;
	private const int WS_EX_TOOLWINDOW = 0x00000080;
	private const int WS_EX_APPWINDOW = 0x00040000;

	[DllImport("user32.dll")]
	private static extern int GetWindowLong(IntPtr hwnd, int index);

	[DllImport("user32.dll")]
	private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

	[DllImport("user32.dll")]
	private static extern bool SetWindowPos(IntPtr hwnd, IntPtr hwndInsertAfter, int x, int y, int width, int height, uint flags);

	public override void _Ready()
	{
		// 在游戏启动时调用隐藏任务栏图标的函数
		CallDeferred("HideFromTaskbar");
	}

	// 公共方法，供其他脚本调用
	public void HideTaskbarIcon()
	{
		CallDeferred("HideFromTaskbar");
	}

	private void HideFromTaskbar()
	{
		if (OS.GetName() == "Windows")
		{
			// 获取窗口句柄
			IntPtr handle = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle;
			
			// 修改窗口样式
			int exStyle = GetWindowLong(handle, GWL_EXSTYLE);
			exStyle = (exStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
			SetWindowLong(handle, GWL_EXSTYLE, exStyle);
			
			// 刷新窗口
			SetWindowPos(handle, IntPtr.Zero, 0, 0, 0, 0, 
				0x0001 | 0x0002 | 0x0020); // SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED
		}
	}
}
