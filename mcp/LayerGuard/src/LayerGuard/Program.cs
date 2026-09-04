using LayerGuard;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

if (args.Length > 0 && !args[0].StartsWith('-'))
    return RunCommandLine(args);

var builder = Host.CreateApplicationBuilder(args);
builder.Logging.AddConsole(options => options.LogToStandardErrorThreshold = LogLevel.Trace);
builder.Services.AddMcpServer().WithStdioServerTransport().WithToolsFromAssembly();
await builder.Build().RunAsync();
return 0;

static int RunCommandLine(string[] args)
{
    Console.OutputEncoding = System.Text.Encoding.UTF8;
    var command = args[0].ToLowerInvariant();
    var positional = args.Skip(1).Where(argument => !argument.StartsWith("--")).ToArray();
    var configPath = ValueOf(args, "--config");

    try
    {
        switch (command)
        {
            case "check":
                {
                    var report = Analyzer.Analyze(Require(positional, "check <path>"), configPath);
                    Console.WriteLine(
                        ValueOf(args, "--format") == "json"
                            ? ReportWriter.ToJson(report)
                            : ReportWriter.ToMarkdown(report)
                    );
                    return report.ViolationCount == 0 ? 0 : 1;
                }

            case "scan":
                {
                    var result = Scanner.Scan(
                        Require(positional, "scan <path>"),
                        ValueOf(args, "--select") ?? "projects",
                        configPath,
                        ValueOf(args, "--ring"),
                        ValueOf(args, "--module"),
                        ValueOf(args, "--name")
                    );
                    Console.WriteLine(ReportWriter.ToJson(result));
                    return 0;
                }

            case "rules":
                {
                    var start = positional.FirstOrDefault() ?? Directory.GetCurrentDirectory();
                    Console.WriteLine(RuleDescription.Render(Ruleset.Load(start, configPath)));
                    return 0;
                }

            default:
                Console.Error.WriteLine(Usage);
                return 2;
        }
    }
    catch (Exception error)
    {
        Console.Error.WriteLine(error.Message);
        return 2;
    }
}

static string Require(string[] positional, string usage) =>
    positional.FirstOrDefault() ?? throw new ArgumentException($"Usage: layerguard {usage}");

static string? ValueOf(string[] args, string name)
{
    var index = Array.IndexOf(args, name);
    return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
}

public static partial class Program
{
    public const string Usage = """
        layerguard — Clean Architecture layer check for .NET

        With no arguments it speaks the Model Context Protocol over stdin/stdout.

        Commands:
          check   <path> [--config <file>] [--format json] every rule the rule file states
          scan    <path> [--select projects|packages|imports|declarations] [--config <file>]
          rules   [<path>] [--config <file>]               show the rules that would apply

        Exit code from `check`: 0 clean, 1 violations found, 2 could not run.
        """;
}
