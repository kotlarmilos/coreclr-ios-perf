using Foundation;
using UIKit;
using System.Runtime.InteropServices;

namespace SampleiOS;

[Register("AppDelegate")]
public class AppDelegate : UIApplicationDelegate
{
	public override UIWindow? Window { get; set; }

	private static ulong startDate;
	private static ulong date;

	[DllImport("__Internal")]
	private static extern int gettimeofday(ref TimeVal tv, IntPtr tz);

	[StructLayout(LayoutKind.Sequential)]
	private struct TimeVal
	{
		public long tv_sec;
		public int tv_usec;
	}

	private static void DebugLaunchTimePrint(string msg)
	{
		var tv = new TimeVal();
		gettimeofday(ref tv, IntPtr.Zero);
		ulong unow = (ulong)tv.tv_sec * 1000000UL + (ulong)tv.tv_usec;

		if (startDate == 0)
		{
			startDate = unow;
			date = startDate;
		}

		Console.Error.WriteLine($"[PERF] {msg}: {unow - date} us Total: {unow - startDate} us");
		date = unow;
	}

	public override bool FinishedLaunching(UIApplication application, NSDictionary? launchOptions)
	{
		DebugLaunchTimePrint("didFinishLaunchingWithOptions begin");

		Window = new UIWindow(UIScreen.MainScreen.Bounds);
		Window.RootViewController = new UIViewController();
		Window.MakeKeyAndVisible();

		DebugLaunchTimePrint("didFinishLaunchingWithOptions end");
		return true;
	}
}
