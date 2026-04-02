namespace IFX.Modules.Transaction.Domain.Common;
public interface IAuditableEntity
{
    Guid? CreatedBy { get; set; }
    DateTime CreatedAt { get; set; }
    DateTime UpdatedAt { get; set; }
}
