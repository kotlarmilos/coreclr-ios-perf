namespace MyMauiApp;

public partial class MainPage : ContentPage
{
	int count = 0;

	public MainPage()
	{
		InitializeComponent();
		
		// Display runtime information
		var runtimeInfo = GetRuntimeInfo();
		HelloLabel.Text = $@"=== Runtime Information ===
{runtimeInfo}
==========================";
	}
	
	private string GetRuntimeInfo()
	{
		var frameworkDescription = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription;
		var processArchitecture = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture;
		var osDescription = System.Runtime.InteropServices.RuntimeInformation.OSDescription;
		
		// Check if running on CoreCLR or Mono
		bool isMono = typeof(object).Assembly.GetType("Mono.RuntimeStructs") != null;
		var runtime = $"Hello World {(isMono ? "from Mono!" : "from CoreCLR!")}";
		
		// Check if ReadyToRun composite is loaded
		bool hasR2RComposite = System.IO.File.Exists(System.IO.Path.Combine(
			AppContext.BaseDirectory, "MyMauiApp.r2r.dylib"));
		
		return $@"Runtime: {runtime}
Framework: {frameworkDescription}
Architecture: {processArchitecture}
OS: {osDescription}
R2R Composite Dylib: {(hasR2RComposite ? "Loaded" : "Not Found")}";
	}

	private void OnCounterClicked(object sender, EventArgs e)
	{
		count++;

		if (count == 1)
			CounterBtn.Text = $"Clicked {count} time";
		else
			CounterBtn.Text = $"Clicked {count} times";

		SemanticScreenReader.Announce(CounterBtn.Text);
	}
}

