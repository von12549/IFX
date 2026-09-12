using System.Data.Common;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

namespace IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;

public sealed class AuthSchemaFingerprintVerifier(IfxDbContext context)
{
    private readonly SchemaFingerprint _expected = AuthBaselineSchemaFingerprint.Create(context);

    public string ExpectedSha256 => _expected.Sha256();

    public async Task<SchemaFingerprintVerification> VerifyAsync(
        DbConnection connection,
        DbTransaction? transaction,
        CancellationToken cancellationToken = default)
    {
        var actual = await SqlServerSchemaFingerprintReader.ReadAsync(
            connection,
            transaction,
            ModuleDatabase.Schema,
            cancellationToken);
        return SchemaFingerprintComparer.Verify(_expected, actual);
    }
}
