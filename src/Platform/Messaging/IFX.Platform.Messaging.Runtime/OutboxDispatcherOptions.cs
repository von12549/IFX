namespace IFX.Platform.Messaging.Runtime;

public sealed class OutboxDispatcherOptions
{
    public int BatchSize { get; init; } = 50;
    public TimeSpan PollInterval { get; init; } = TimeSpan.FromSeconds(1);
    public TimeSpan LeaseDuration { get; init; } = TimeSpan.FromMinutes(1);
    public TimeSpan SendTimeout { get; init; } = TimeSpan.FromSeconds(30);
    public int MaximumAttempts { get; init; } = 8;
    public TimeSpan MaximumBackoff { get; init; } = TimeSpan.FromMinutes(15);

    public void Validate()
    {
        if (BatchSize is < 1 or > 1000 || PollInterval <= TimeSpan.Zero || LeaseDuration <= SendTimeout || MaximumAttempts < 1 || MaximumBackoff <= TimeSpan.Zero)
        {
            throw new InvalidOperationException("Invalid durable dispatcher tuning.");
        }
    }
}
