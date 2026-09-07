namespace IFX.ApiHost.Runtime;

public sealed class RuntimeDrainOptions
{
    public const string SectionName = "Runtime:Drain";

    public TimeSpan OperationBudget { get; init; } = TimeSpan.FromSeconds(10);
    public TimeSpan HandlerBudget { get; init; } = TimeSpan.FromSeconds(20);
    public TimeSpan LeaseBudget { get; init; } = TimeSpan.FromSeconds(30);
    public TimeSpan ProcessGrace { get; init; } = TimeSpan.FromSeconds(40);
    public TimeSpan OrchestratorKill { get; init; } = TimeSpan.FromSeconds(45);
    public TimeSpan TelemetryFlushReserve { get; init; } = TimeSpan.FromSeconds(2);

    public void Validate()
    {
        if (OperationBudget <= TimeSpan.Zero ||
            OperationBudget >= HandlerBudget ||
            HandlerBudget >= LeaseBudget ||
            LeaseBudget >= ProcessGrace ||
            ProcessGrace >= OrchestratorKill)
        {
            throw new InvalidOperationException(
                "G04-DRAIN-BUDGET-INVALID: operation < handler < lease < process grace < orchestrator kill is required.");
        }

        if (TelemetryFlushReserve <= TimeSpan.Zero || TelemetryFlushReserve >= ProcessGrace)
        {
            throw new InvalidOperationException(
                "G04-DRAIN-FLUSH-RESERVE-INVALID: telemetry reserve must be positive and shorter than process grace.");
        }
    }
}
