using IFX.Modules.Registry.Application.Events;
using IFX.Modules.Registry.Contracts.V1.Events;

namespace IFX.Modules.Registry.Infrastructure.Messaging;

public static class ClassStatusChangedV1Mapper
{
    public static ClassStatusChangedV1 Map(ClassStatusChanged fact) => new(
        fact.ClassId,
        fact.FundId,
        fact.OldStatus,
        fact.NewStatus);
}
