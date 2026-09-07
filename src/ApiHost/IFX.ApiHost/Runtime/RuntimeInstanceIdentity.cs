using System.Text.RegularExpressions;

namespace IFX.ApiHost.Runtime;

public sealed record RuntimeInstanceIdentity(string Value)
{
    private const int MaximumLength = 128;

    public static RuntimeInstanceIdentity Create(RuntimeRole role, string? machineName = null, int? processId = null)
    {
        var machine = Regex.Replace(machineName ?? Environment.MachineName, "[^a-zA-Z0-9-]", "-").Trim('-').ToLowerInvariant();
        if (string.IsNullOrEmpty(machine)) machine = "host";
        if (machine.Length > 40) machine = machine[..40];
        var value = $"ifx-{role.ToString().ToLowerInvariant()}-{machine}-{processId ?? Environment.ProcessId}-{Guid.NewGuid():N}";
        return new RuntimeInstanceIdentity(value.Length <= MaximumLength ? value : value[..MaximumLength]);
    }
}
