using UUIDNext;
namespace IFX.Modules.Transaction.Domain.Common;
public abstract class BaseEntity
{
    public Guid Id { get; protected set; } = Uuid.NewSequential();
}
