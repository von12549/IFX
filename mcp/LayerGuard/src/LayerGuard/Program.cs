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
                    var baselinePath = ValueOf(args, "--baseline");
                    if (baselinePath is not null)
                        report = Baseline.Apply(report, baselinePath);
                    var rendered = ValueOf(args, "--format") == "json"
                        ? ReportWriter.ToJson(report)
                        : ReportWriter.ToMarkdown(report);
                    var reportPath = ValueOf(args, "--report");
                    if (reportPath is not null)
                        File.WriteAllText(Paths.Normalize(reportPath), rendered + Environment.NewLine);
                    if (!args.Contains("--quiet", StringComparer.OrdinalIgnoreCase))
                        Console.WriteLine(rendered);
                    return report.Baseline is null
                        ? report.ViolationCount == 0 ? 0 : 1
                        : report.Baseline.New == 0 && report.Baseline.Stale == 0 ? 0 : 1;
                }

            case "snapshot":
                {
                    var report = Analyzer.Analyze(Require(positional, "snapshot <path>"), configPath);
                    var output = ValueOf(args, "--output")
                        ?? throw new ArgumentException("snapshot requires --output <file>.");
                    var owner = ValueOf(args, "--owner")
                        ?? throw new ArgumentException("snapshot requires --owner <name>.");
                    var expires = DateOnly.Parse(ValueOf(args, "--expires")
                        ?? throw new ArgumentException("snapshot requires --expires yyyy-MM-dd."));
                    var reason = ValueOf(args, "--reason") ?? "03-A0 bootstrap historical violation";
                    var removal = ValueOf(args, "--removal") ?? "Remove when the owning migration item is complete.";
                    Baseline.Write(Baseline.Snapshot(report, owner, reason, expires, removal), output);
                    Console.WriteLine($"Wrote {report.ViolationCount} baseline entries to {Paths.Normalize(output)}.");
                    return 0;
                }
            case "graph":
                {
                    var graph = ArchitectureGraph.Build(Require(positional, "graph <path>"), configPath);
                    var rendered = ReportWriter.ToJson(graph);
                    var reportPath = ValueOf(args, "--report");
                    if (reportPath is not null)
                        File.WriteAllText(Paths.Normalize(reportPath), rendered + Environment.NewLine);
                    if (!args.Contains("--quiet", StringComparer.OrdinalIgnoreCase))
                        Console.WriteLine(rendered);
                    return 0;
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
          check   <path> [--config <file>] [--baseline <file>] [--report <file>] [--format json] [--quiet]
          snapshot <path> --output <file> --owner <name> --expires yyyy-MM-dd [--config <file>]
          graph   <path> [--config <file>] [--report <file>] [--quiet]
          scan    <path> [--select projects|packages|imports|declarations] [--config <file>]
          rules   [<path>] [--config <file>]               show the rules that would apply

        Exit code from `check`: 0 clean, 1 violations found, 2 could not run.
        """;
}
