using App.Abstractions;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Auth.Composition
{
    public sealed class AuthMigrator : IAppMigrator
    {
        public string Name => "Auth";

        // The 14 old migration IDs that were squashed into the baseline InitialCreate.
        // If any of these are present in __EFMigrationsHistory, the database is an
        // existing deployment that needs its history updated before MigrateAsync runs.
        private static readonly string[] OldMigrationIds =
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
            "20260123042554_AddEmailVerificationToken",
        ];

        private const string SquashedInitialCreateId = "20260317145706_InitialCreate";
        private const string EfProductVersion = "8.0.0";

        public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
        {
            Log.Information("[{Module}] Starting database migration...", Name);

            var db = sp.GetRequiredService<IfxDbContext>();

            await HandleSquashedMigrationHistoryAsync(db, ct);

            var pendingMigrations = await db.Database.GetPendingMigrationsAsync(ct);
            var pendingCount = pendingMigrations.Count();

            if (pendingCount > 0)
            {
                Log.Information("[{Module}] Applying {Count} pending migration(s)...", Name, pendingCount);
                foreach (var migration in pendingMigrations)
                {
                    Log.Debug("[{Module}] Pending migration: {Migration}", Name, migration);
                }
            }
            else
            {
                Log.Information("[{Module}] No pending migrations", Name);
            }

            await db.Database.MigrateAsync(ct);

            Log.Information("[{Module}] Database migration completed successfully", Name);
        }

        /// <summary>
        /// Detects existing databases that were at the 14-migration history and replaces
        /// those rows with the single squashed InitialCreate row, so MigrateAsync does not
        /// try to re-create tables that already exist.
        /// </summary>
        private async Task HandleSquashedMigrationHistoryAsync(IfxDbContext db, CancellationToken ct)
        {
            var applied = (await db.Database.GetAppliedMigrationsAsync(ct)).ToHashSet();

            // Nothing to fix if old migrations are not present
            if (!OldMigrationIds.Any(applied.Contains))
                return;

            Log.Warning(
                "[{Module}] Detected legacy migration history (pre-squash). " +
                "Replacing {Count} old rows with squashed baseline '{Id}'...",
                Name, OldMigrationIds.Length, SquashedInitialCreateId);

            // Build parameterised DELETE for each old ID to avoid SQL injection
            foreach (var id in OldMigrationIds)
            {
                if (!applied.Contains(id))
                    continue;

                await db.Database.ExecuteSqlRawAsync(
                    "DELETE FROM [__EFMigrationsHistory] WHERE [MigrationId] = {0}",
                    [id], ct);
            }

            // Insert the squashed InitialCreate row (only if not already present)
            if (!applied.Contains(SquashedInitialCreateId))
            {
                await db.Database.ExecuteSqlRawAsync(
                    "INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ({0}, {1})",
                    [SquashedInitialCreateId, EfProductVersion], ct);
            }

            Log.Information("[{Module}] Migration history updated successfully", Name);
        }
    }
}
