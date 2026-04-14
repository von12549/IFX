namespace IFX.BuildingBlocks.Domain;

public interface IAuditableEntity
{
    Guid? CreatedBy { get; set; }
    Guid? UpdatedBy { get; set; }
    DateTime CreatedAt { get; set; }
    DateTime UpdatedAt { get; set; }
}
