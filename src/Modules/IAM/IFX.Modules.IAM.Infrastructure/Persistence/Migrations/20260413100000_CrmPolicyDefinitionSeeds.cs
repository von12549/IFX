using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.IAM.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CrmPolicyDefinitionSeeds : Migration
    {
        // ── UUID v7 Stable Seed IDs ────────────────────────────────────────────────
        // Base timestamp: 2026-01-01T00:00:00.000Z (ms = 0x019B76DAA800)
        // Format: 019B76DA-A800-7{group:03X}-8000-{seq:012X}
        //
        // Group 007 — Users (for admin seeder reference)
        private const string AdminUserId            = "019B76DA-A800-7007-8000-000000000001";
        // Group 00D — CRM PolicyDefinitions
        private const string PolicyPartyList        = "019B76DA-A800-700D-8000-000000000001";
        private const string PolicyPartyRead        = "019B76DA-A800-700D-8000-000000000002";
        private const string PolicyPartyCreate      = "019B76DA-A800-700D-8000-000000000003";
        private const string PolicyPartyUpdate      = "019B76DA-A800-700D-8000-000000000004";
        private const string PolicyPartyDelete      = "019B76DA-A800-700D-8000-000000000005";
        private const string PolicyInvestorList     = "019B76DA-A800-700D-8000-000000000006";
        private const string PolicyInvestorRead     = "019B76DA-A800-700D-8000-000000000007";
        private const string PolicyInvestorCreate   = "019B76DA-A800-700D-8000-000000000008";
        private const string PolicyInvestorUpdate   = "019B76DA-A800-700D-8000-000000000009";
        private const string PolicyInvestorDelete   = "019B76DA-A800-700D-8000-00000000000A";
        private const string PolicyInvAccList       = "019B76DA-A800-700D-8000-00000000000B";
        private const string PolicyInvAccRead       = "019B76DA-A800-700D-8000-00000000000C";
        private const string PolicyInvAccCreate     = "019B76DA-A800-700D-8000-00000000000D";
        private const string PolicyInvAccUpdate     = "019B76DA-A800-700D-8000-00000000000E";
        private const string PolicyInvAccDelete     = "019B76DA-A800-700D-8000-00000000000F";

        // Condition JSON fragments
        private const string ST       = @"[{""TemplateName"":""SameTenant"",""Parameters"":null}]";

        private const string SeedDate = "2026-04-13 10:00:00";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ── CRM PolicyDefinitions — platform defaults (15 rows) ───────────────
            migrationBuilder.Sql($@"
DECLARE @UserId UNIQUEIDENTIFIER = '{AdminUserId}'
DECLARE @Now    DATETIME2        = '{SeedDate}'

INSERT INTO auth.PolicyDefinitions
    (Id, TenantId, Scope, Name, Description, ResourceType, Action, ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
SELECT v.Id, NULL, 1, v.Name, v.Description, v.ResourceType, v.Action, v.Conditions, 1, @UserId, @UserId, @Now, @Now
FROM (VALUES
    ('{PolicyPartyList}',    'List Parties (Platform Default)',               'Allows listing all parties within the same tenant.',                              'party',              'list',   '{ST}'),
    ('{PolicyPartyRead}',    'Read Party (Platform Default)',                 'Allows reading a party within the same tenant.',                                  'party',              'read',   '{ST}'),
    ('{PolicyPartyCreate}',  'Create Party (Platform Default)',               'Allows creating a new party within the same tenant.',                             'party',              'create', '{ST}'),
    ('{PolicyPartyUpdate}',  'Update Party (Platform Default)',               'Allows updating a party within the same tenant.',                                 'party',              'update', '{ST}'),
    ('{PolicyPartyDelete}',  'Delete Party (Platform Default)',               'Allows deleting a party within the same tenant.',                                 'party',              'delete', '{ST}'),
    ('{PolicyInvestorList}', 'List Investors (Platform Default)',             'Allows listing all investors within the same tenant.',                            'investor',           'list',   '{ST}'),
    ('{PolicyInvestorRead}', 'Read Investor (Platform Default)',              'Allows reading an investor within the same tenant.',                              'investor',           'read',   '{ST}'),
    ('{PolicyInvestorCreate}','Create Investor (Platform Default)',           'Allows creating a new investor within the same tenant.',                          'investor',           'create', '{ST}'),
    ('{PolicyInvestorUpdate}','Update Investor (Platform Default)',           'Allows updating an investor within the same tenant.',                             'investor',           'update', '{ST}'),
    ('{PolicyInvestorDelete}','Delete Investor (Platform Default)',           'Allows deleting an investor within the same tenant.',                             'investor',           'delete', '{ST}'),
    ('{PolicyInvAccList}',   'List Investment Accounts (Platform Default)',   'Allows listing all investment accounts within the same tenant.',                  'investment-account', 'list',   '{ST}'),
    ('{PolicyInvAccRead}',   'Read Investment Account (Platform Default)',    'Allows reading an investment account within the same tenant.',                    'investment-account', 'read',   '{ST}'),
    ('{PolicyInvAccCreate}', 'Create Investment Account (Platform Default)',  'Allows creating a new investment account within the same tenant.',                'investment-account', 'create', '{ST}'),
    ('{PolicyInvAccUpdate}', 'Update Investment Account (Platform Default)',  'Allows updating an investment account within the same tenant.',                   'investment-account', 'update', '{ST}'),
    ('{PolicyInvAccDelete}', 'Delete Investment Account (Platform Default)',  'Allows deleting an investment account within the same tenant.',                   'investment-account', 'delete', '{ST}')
) AS v(Id, Name, Description, ResourceType, Action, Conditions)
WHERE NOT EXISTS (SELECT 1 FROM auth.PolicyDefinitions p WHERE p.Id = v.Id)
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($@"
DELETE FROM auth.PolicyDefinitions
WHERE Id IN (
    '{PolicyPartyList}', '{PolicyPartyRead}', '{PolicyPartyCreate}', '{PolicyPartyUpdate}', '{PolicyPartyDelete}',
    '{PolicyInvestorList}', '{PolicyInvestorRead}', '{PolicyInvestorCreate}', '{PolicyInvestorUpdate}', '{PolicyInvestorDelete}',
    '{PolicyInvAccList}', '{PolicyInvAccRead}', '{PolicyInvAccCreate}', '{PolicyInvAccUpdate}', '{PolicyInvAccDelete}'
)
");
        }
    }
}
