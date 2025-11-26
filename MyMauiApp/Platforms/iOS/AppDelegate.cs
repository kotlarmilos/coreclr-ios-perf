using Foundation;
using UIKit;
using System.Runtime.InteropServices;

namespace MyMauiApp;

[Register("AppDelegate")]
public class AppDelegate : MauiUIApplicationDelegate
{
	[DllImport("__Internal")]
	private static extern int clock_gettime(int clockId, ref TimeSpec tp);

	[StructLayout(LayoutKind.Sequential)]
	private struct TimeSpec
	{
		public long tv_sec;
		public long tv_nsec;
	}

	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();

	public override bool FinishedLaunching(UIApplication application, NSDictionary launchOptions)
	{
		// Call base first to let MAUI initialize
		var result = base.FinishedLaunching(application, launchOptions);
		
		// Phase 9 measurement - after MAUI initialization complete using CLOCK_MONOTONIC
		var ts = new TimeSpec();
		int ret = clock_gettime(6, ref ts); // 6 = CLOCK_MONOTONIC_RAW
		Console.Error.WriteLine($"[PERF] RuntimeInit - clock_gettime return={ret}, didFinishLaunchingWithOptions: END at {ts.tv_sec}.{ts.tv_nsec:D9}");
		
		return result;
	}
}
