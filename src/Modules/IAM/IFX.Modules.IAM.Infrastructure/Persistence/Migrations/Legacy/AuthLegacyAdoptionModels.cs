using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

namespace IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;

public enum AuthLegacyAdoptionClassification
{
    AlreadyCanonical,
    PreSquashHistory,
    IncorrectSquashAlias,
    ExplicitAdoptionRequired,
    EnsureCreatedAdoption,
    Invalid
}

public sealed record AuthLegacyAdoptionPlan(
    AuthLegacyAdoptionClassification Classification,
    IReadOnlyList<string> TargetRowsToDelete,
    MigrationHistoryRow? CanonicalRowToInsert,
    IReadOnlyList<string> Errors)
{
    public bool CanApply => Errors.Count == 0;

    public bool HasChanges => TargetRowsToDelete.Count > 0 || CanonicalRowToInsert is not null;
}
