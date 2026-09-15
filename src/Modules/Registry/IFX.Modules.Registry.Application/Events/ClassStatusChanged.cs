namespace IFX.Modules.Registry.Application.Events;

public sealed record ClassStatusChanged(Guid ClassId, Guid FundId, string OldStatus, string NewStatus);
