using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations.Legacy;

public static class AuthLegacyMigrationManifest
{
    public const string CanonicalInitialCreateId = "20260327075710_InitialCreate";
    public const string IncorrectSquashAlias = "20260317145706_InitialCreate";

    public static IReadOnlyList<string> PreSquashMigrationIds { get; } =
    [
        "20251222160950_InitialCreate",
        "20251224110859_AddBirthDateToUsers",
        "20260106033815_AddUserRoles",
        "20260107055630_AddSsoUserRole",
        "20260110091959_AddIssuerToUsers",
        "20260110095019_RenameColumn_CognitoUserId_To_Subject",
        "20260111031731_AddIdpTable",
        "20260111120403_RenameSchemaFromCognitoToAuth",
        "20260111122753_SplitUserTableIntoUserAndUserIdentity",
        "20260111123319_DropUsersBackupTable",
        "20260114025631_AddIdpTypeColumn",
        "20260114125506_AddIsPrimaryToIdp",
        "20260116100000_AddPendingRole",
        "20260123042554_AddEmailVerificationToken"
    ];

    public static IReadOnlyList<string> AllLegacyIds { get; } =
        [.. PreSquashMigrationIds, IncorrectSquashAlias];

    public static string GetCanonicalProductVersion(IfxDbContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var assembly = context.GetService<IMigrationsAssembly>();
        if (!assembly.Migrations.TryGetValue(CanonicalInitialCreateId, out var migrationType))
        {
            throw new HistoryBootstrapException(
                $"Auth migration assembly does not contain canonical migration '{CanonicalInitialCreateId}'.");
        }

        return assembly.CreateMigration(migrationType, context.Database.ProviderName!)
            .TargetModel
            .GetProductVersion() ?? throw new HistoryBootstrapException(
                "Auth canonical migration does not declare an EF ProductVersion.");
    }
}
