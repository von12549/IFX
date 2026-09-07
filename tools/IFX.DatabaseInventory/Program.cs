using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

var options = Arguments.Parse(args);
var root = Path.GetFullPath(options.Root);
var moduleSpecs = new ModuleSpec[]
{
    new("Auth", "auth", "AuthDatabase", 10,
        "src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Persistence/Migrations",
        "src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Persistence/IfxDbContext.cs",
        () => new IfxDbContext(SqlOptions<IfxDbContext>())),
    new("CRM", "crm", "CrmDatabase", 20,
        "src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Migrations",
        "src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Persistence/CrmDbContext.cs",
        () => new CrmDbContext(SqlOptions<CrmDbContext>())),
    new("Registry", "registry", "RegistryDatabase", 30,
        "src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Migrations",
        "src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Persistence/RegistryDbContext.cs",
        () => new RegistryDbContext(SqlOptions<RegistryDbContext>())),
    new("Holdings", "holdings", "HoldingsDatabase", 40,
        "src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Migrations",
        "src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Persistence/HoldingsDbContext.cs",
        () => new HoldingsDbContext(SqlOptions<HoldingsDbContext>())),
    new("Transaction", "transaction", "TransactionDatabase", 50,
        "src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Migrations",
        "src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Persistence/TransactionDbContext.cs",
        () => new TransactionDbContext(SqlOptions<TransactionDbContext>()))
};

var modules = moduleSpecs.Select(spec => InspectModule(root, spec)).ToArray();
var staticScan = ScanSources(root, moduleSpecs);
var connectionSurfaces = InspectConnectionSurfaces(root, moduleSpecs);
var authLegacy = InspectAuthLegacy(root);

var report = new
{
    formatVersion = 1,
    physicalDatabase = "IFXDb",
    historyBaseline = new
    {
        current = "dbo.__EFMigrationsHistory",
        target = moduleSpecs.ToDictionary(
            spec => spec.Name,
            spec => $"{spec.Schema}.__EFMigrationsHistory")
    },
    modules,
    staticScan,
    connectionSurfaces,
    knownDatabaseStates = new object[]
    {
        new { name = "fresh", signal = "No module tables and no migration history", classification = "safe", action = "Apply canonical module migrations" },
        new { name = "current-shared-history", signal = "Known catalog in dbo.__EFMigrationsHistory", classification = "bootstrap-required", action = "Copy exact owned IDs to module histories, retain shared history read-only" },
        new { name = "ensure-created", signal = "Complete module schema fingerprint and no history", classification = "explicit-adoption-only", action = "Adopt only after full fingerprint match" },
        new { name = "auth-pre-squash-14", signal = string.Join(",", authLegacy.LegacyIds), classification = "known-legacy", action = "Normalize transactionally to canonical Auth InitialCreate" },
        new { name = "auth-wrong-squash-alias", signal = authLegacy.WrongAlias, classification = "known-legacy", action = "Recognize as alias; normalize to canonical ID" },
        new { name = "unknown-or-partial", signal = "Unknown history ID or incomplete schema fingerprint", classification = "fail-closed", action = "Do not stamp or migrate automatically" }
    },
    schemaSamples = new
    {
        repositoryModel = "Complete compiled EF model and migration catalogs in this report; contains no rows or secrets",
        testDatabase = "Phase 7 will capture SQL Server metadata-only fixtures",
        productionDatabase = new
        {
            status = "external-evidence-gap",
            owner = "Database Operations",
            collection = "Export metadata-only sys.schemas/sys.tables/sys.columns/sys.indexes/sys.foreign_keys and migration-history rows after redacting server, login, and business data"
        }
    }
};

var output = Path.GetFullPath(Path.Combine(root, options.Output));
Directory.CreateDirectory(Path.GetDirectoryName(output)!);
var json = JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true });
File.WriteAllText(output, json + Environment.NewLine);

var manifest = new
{
    formatVersion = 1,
    physicalDatabase = "IFXDb",
    modules = modules.Select(module => new
    {
        module = module.Module,
        order = module.Order,
        dbContext = module.DbContext,
        migrationAssembly = module.MigrationAssembly,
        schema = module.Schema,
        historyTable = module.TargetHistory,
        connectionKey = module.ConnectionKey,
        migrations = module.Migrations
    }).ToArray()
};
var manifestOutput = Path.GetFullPath(Path.Combine(root, options.ManifestOutput));
Directory.CreateDirectory(Path.GetDirectoryName(manifestOutput)!);
File.WriteAllText(
    manifestOutput,
    JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true }) + Environment.NewLine);

var violations = modules.SelectMany(module => module.SchemaViolations)
    .Concat(staticScan.CrossSchemaFindings)
    .ToArray();
var duplicateMigrationIds = modules.SelectMany(module => module.Migrations)
    .GroupBy(migration => migration.MigrationId, StringComparer.Ordinal)
    .Where(group => group.Count() > 1)
    .Select(group => group.Key)
    .ToArray();
if (violations.Length > 0)
{
    Console.Error.WriteLine($"Database inventory found {violations.Length} schema ownership violation(s). Report: {output}");
    return 2;
}

if (modules.Length != 5 || modules.Any(module => module.Migrations.Length == 0) || duplicateMigrationIds.Length > 0)
{
    Console.Error.WriteLine("Database inventory has a missing module/catalog or duplicate MigrationId.");
    return 3;
}

Console.WriteLine($"Database inventory generated: {output}");
Console.WriteLine($"Migration manifest generated: {manifestOutput}");
Console.WriteLine($"Modules: {modules.Length}; entities: {modules.Sum(module => module.Entities.Length)}; migrations: {modules.Sum(module => module.Migrations.Length)}; schema violations: 0");
return 0;

static DbContextOptions<TContext> SqlOptions<TContext>() where TContext : DbContext =>
    new DbContextOptionsBuilder<TContext>()
        .UseSqlServer("Server=localhost;Database=InventoryOnly;User Id=inventory;Password=not-used;TrustServerCertificate=True")
        .Options;

static ModuleInventory InspectModule(string root, ModuleSpec spec)
{
    using var context = spec.CreateContext();
    var model = context.GetService<IDesignTimeModel>().Model;
    var entities = model.GetEntityTypes()
        .Select(entity =>
        {
            var table = entity.GetTableName();
            var schema = entity.GetSchema();
            var store = table is null ? (StoreObjectIdentifier?)null : StoreObjectIdentifier.Table(table, schema);
            var primaryKey = entity.FindPrimaryKey();
            return new EntityInventory(
                entity.ClrType.FullName ?? entity.Name,
                table,
                schema,
                entity.IsOwned(),
                primaryKey?.Properties.Select(property => property.Name).Order().ToArray() ?? [],
                entity.GetKeys().Select(key => new KeyInventory(
                        key.GetName(),
                        key.Properties.Select(property => property.Name).ToArray(),
                        key.IsPrimaryKey()))
                    .OrderBy(key => key.Name)
                    .ToArray(),
                entity.GetIndexes().Select(index => new IndexInventory(
                        index.GetDatabaseName(),
                        index.Properties.Select(property => property.Name).ToArray(),
                        index.IsUnique))
                    .OrderBy(index => index.Name)
                    .ToArray(),
                entity.GetForeignKeys().Select(foreignKey => new ForeignKeyInventory(
                        foreignKey.GetConstraintName(),
                        foreignKey.Properties.Select(property => property.Name).ToArray(),
                        foreignKey.PrincipalEntityType.GetSchema(),
                        foreignKey.PrincipalEntityType.GetTableName()))
                    .OrderBy(foreignKey => foreignKey.Name)
                    .ToArray(),
                entity.GetCheckConstraints().Select(checkConstraint => new CheckConstraintInventory(
                        checkConstraint.Name,
                        checkConstraint.Sql))
                    .OrderBy(checkConstraint => checkConstraint.Name)
                    .ToArray(),
                store is null
                    ? []
                    : entity.GetProperties()
                        .Select(property => new ColumnInventory(
                            property.Name,
                            property.GetColumnName(store.Value),
                            property.GetColumnType(),
                            property.IsNullable))
                        .OrderBy(column => column.Name)
                        .ToArray());
        })
        .OrderBy(entity => entity.Entity)
        .ToArray();

    var assembly = context.GetService<IMigrationsAssembly>();
    var migrationsDirectory = Path.Combine(root, spec.MigrationsPath.Replace('/', Path.DirectorySeparatorChar));
    var migrations = assembly.Migrations
        .OrderBy(pair => pair.Key, StringComparer.Ordinal)
        .Select(pair =>
        {
            var migration = assembly.CreateMigration(pair.Value, context.Database.ProviderName!);
            var source = Directory.GetFiles(migrationsDirectory, $"{pair.Key}*.cs", SearchOption.TopDirectoryOnly)
                .Single(path => !path.EndsWith(".Designer.cs", StringComparison.OrdinalIgnoreCase));
            var relativeSource = Relative(root, source);
            var upBody = ExtractUpBody(File.ReadAllText(source));
            return new MigrationInventory(
                pair.Key,
                migration.TargetModel.GetProductVersion(),
                relativeSource,
                Sha256(source),
                ClassifyRisk(upBody));
        })
        .ToArray();

    var schemaViolations = entities
        .Where(entity => entity.Table is not null && !string.Equals(entity.Schema, spec.Schema, StringComparison.OrdinalIgnoreCase))
        .Select(entity => $"{spec.Name}: entity {entity.Entity} maps to {entity.Schema ?? "<default>"}.{entity.Table}, expected {spec.Schema}")
        .Concat(entities.SelectMany(entity => entity.ForeignKeys
            .Where(foreignKey => foreignKey.PrincipalTable is not null &&
                                 !string.Equals(foreignKey.PrincipalSchema, spec.Schema, StringComparison.OrdinalIgnoreCase))
            .Select(foreignKey => $"{spec.Name}: FK {foreignKey.Name} points to {foreignKey.PrincipalSchema}.{foreignKey.PrincipalTable}")))
        .Order()
        .ToArray();

    return new ModuleInventory(
        spec.Name,
        spec.Order,
        spec.Schema,
        context.GetType().FullName!,
        context.GetType().Assembly.GetName().Name!,
        spec.ConnectionKey,
        $"{spec.Schema}.__EFMigrationsHistory",
        Relative(root, Path.Combine(root, spec.ContextPath.Replace('/', Path.DirectorySeparatorChar))),
        entities,
        model.GetSequences().Select(sequence => new SequenceInventory(sequence.Name, sequence.Schema)).OrderBy(sequence => sequence.Name).ToArray(),
        migrations,
        schemaViolations);
}

static StaticScanReport ScanSources(string root, IReadOnlyList<ModuleSpec> specs)
{
    var sqlFindings = new List<SourceFinding>();
    var directTableReferences = new List<SourceFinding>();
    var crossSchema = new List<string>();
    var databaseObjectDefinitions = new List<SourceFinding>();
    var sourceFiles = Directory.GetFiles(Path.Combine(root, "src"), "*.cs", SearchOption.AllDirectories)
        .Where(path => !IsBuildOutput(path))
        .Order(StringComparer.Ordinal);
    var schemaNames = specs.Select(spec => spec.Schema).ToArray();

    foreach (var path in sourceFiles)
    {
        var text = File.ReadAllText(path);
        var relative = Relative(root, path);
        var module = specs.FirstOrDefault(spec => relative.Contains($"Modules/{spec.Name}/", StringComparison.OrdinalIgnoreCase));
        foreach (var finding in FindLines(text, @"\b(ExecuteSql(?:Raw|Interpolated)?Async|FromSql(?:Raw|Interpolated)?|SqlQueryRaw|migrationBuilder\.Sql)\b"))
        {
            sqlFindings.Add(new SourceFinding(relative, finding.Line, "raw-sql", finding.Excerpt));
        }

        foreach (var finding in FindLines(text, @"(?i)\bCREATE\s+(?:OR\s+ALTER\s+)?(VIEW|TRIGGER|PROC(?:EDURE)?)\b"))
        {
            databaseObjectDefinitions.Add(new SourceFinding(relative, finding.Line, "database-object-definition", finding.Excerpt));
        }

        foreach (var schema in schemaNames)
        {
            // Bracketed SQL identifiers avoid confusing C# namespaces such as
            // IFX.Modules.Auth.Domain with database access to the auth schema.
            var schemaTablePattern = $@"(?i)\[{Regex.Escape(schema)}\]\s*\.\s*\[[^\]]+\]";
            foreach (var finding in FindLines(text, schemaTablePattern))
            {
                directTableReferences.Add(new SourceFinding(relative, finding.Line, "schema-qualified-table-reference", finding.Excerpt));
                if (module is null)
                {
                    crossSchema.Add($"Outside module ownership: {relative}:{finding.Line} references schema '{schema}'");
                }
                else if (!string.Equals(schema, module.Schema, StringComparison.OrdinalIgnoreCase))
                {
                    crossSchema.Add($"{module.Name}: {relative}:{finding.Line} references foreign schema '{schema}'");
                }
            }
        }

        if (module is null || !relative.Contains("/Migrations/", StringComparison.OrdinalIgnoreCase))
        {
            continue;
        }

        foreach (Match match in Regex.Matches(text, @"(?:schema|principalSchema):\s*""(?<schema>[^""]+)"""))
        {
            var schema = match.Groups["schema"].Value;
            if (schemaNames.Contains(schema, StringComparer.OrdinalIgnoreCase) &&
                !string.Equals(schema, module.Schema, StringComparison.OrdinalIgnoreCase))
            {
                crossSchema.Add($"{module.Name}: {relative} names foreign schema '{schema}'");
            }
        }
    }

    return new StaticScanReport(
        sqlFindings.OrderBy(finding => finding.Path).ThenBy(finding => finding.Line).ToArray(),
        directTableReferences.OrderBy(finding => finding.Path).ThenBy(finding => finding.Line).ToArray(),
        databaseObjectDefinitions.OrderBy(finding => finding.Path).ThenBy(finding => finding.Line).ToArray(),
        crossSchema.Distinct().Order().ToArray());
}

static ConnectionSurfaceReport InspectConnectionSurfaces(string root, IReadOnlyList<ModuleSpec> specs)
{
    var jsonFiles = Directory.GetFiles(Path.Combine(root, "src", "ApiHost"), "appsettings*.json", SearchOption.AllDirectories)
        .Where(path => !IsBuildOutput(path))
        .Order(StringComparer.Ordinal)
        .Select(path =>
        {
            using var document = JsonDocument.Parse(File.ReadAllText(path));
            var entries = new List<ConnectionSetting>();
            if (document.RootElement.TryGetProperty("ConnectionStrings", out var section))
            {
                foreach (var property in section.EnumerateObject().OrderBy(property => property.Name))
                {
                    var value = property.Value.GetString() ?? string.Empty;
                    entries.Add(new ConnectionSetting(
                        property.Name,
                        string.IsNullOrWhiteSpace(value) ? "blank" : "configured",
                        ExtractDatabaseName(value)));
                }
            }

            return new ConfigurationFile(Relative(root, path), entries.ToArray());
        })
        .ToArray();

    var composeFiles = new[] { "docker-compose.yml", "docker-compose.nas.yml" }
        .Where(file => File.Exists(Path.Combine(root, file)))
        .Select(file =>
        {
            var entries = File.ReadLines(Path.Combine(root, file))
                .Select(line => Regex.Match(line, @"ConnectionStrings__(?<key>[A-Za-z0-9_]+)=(?<value>.+)$"))
                .Where(match => match.Success)
                .Select(match => new ComposeConnection(
                    match.Groups["key"].Value,
                    ExtractDatabaseName(match.Groups["value"].Value),
                    match.Groups["value"].Value.Contains("${DB_USER", StringComparison.Ordinal) &&
                    match.Groups["value"].Value.Contains("${DB_PASSWORD", StringComparison.Ordinal)))
                .OrderBy(entry => entry.Key)
                .ToArray();
            return new ComposeFile(file, entries);
        })
        .ToArray();

    var fallbackFindings = Directory.GetFiles(Path.Combine(root, "src", "Modules"), "DependencyInjection.cs", SearchOption.AllDirectories)
        .Where(path => !IsBuildOutput(path))
        .SelectMany(path => FindLines(File.ReadAllText(path), "GetConnectionString\\(\"DefaultConnection\"\\)")
            .Select(finding => new SourceFinding(Relative(root, path), finding.Line, "default-connection-fallback", finding.Excerpt)))
        .OrderBy(finding => finding.Path)
        .ToArray();

    return new ConnectionSurfaceReport(
        specs.Select(spec => spec.ConnectionKey).ToArray(),
        jsonFiles,
        composeFiles,
        fallbackFindings,
        new ExternalEvidenceGap(
            "Database Operations",
            "Environment inventory must map every module key to server/database identity and document DDL/DML grants without exporting connection strings or secrets."),
        "Current Compose uses the same DB_USER/DB_PASSWORD variables for runtime startup migrations; migration/runtime identity separation is not yet implemented.");
}

static AuthLegacyReport InspectAuthLegacy(string root)
{
    var path = Path.Combine(root, "src", "Modules", "Auth", "IFX.Modules.Auth.Composition", "EFMigrator.cs");
    var text = File.ReadAllText(path);
    var ids = Regex.Matches(text, "\\\"(?<id>\\d{14}_[A-Za-z0-9_]+)\\\"")
        .Select(match => match.Groups["id"].Value)
        .ToArray();
    return new AuthLegacyReport(
        ids.Take(14).ToArray(),
        ids.Skip(14).FirstOrDefault() ?? "<missing>",
        "20260327075710_InitialCreate");
}

static IReadOnlyList<(int Line, string Excerpt)> FindLines(string text, string pattern)
{
    var regex = new Regex(pattern);
    return text.Replace("\r\n", "\n", StringComparison.Ordinal).Split('\n')
        .Select((line, index) => (Line: index + 1, Text: line))
        .Where(item => regex.IsMatch(item.Text))
        .Select(item => (item.Line, item.Text.Trim().Length <= 180 ? item.Text.Trim() : item.Text.Trim()[..180]))
        .ToArray();
}

static string ExtractUpBody(string source)
{
    var up = source.IndexOf("protected override void Up", StringComparison.Ordinal);
    var down = source.IndexOf("protected override void Down", StringComparison.Ordinal);
    return up >= 0 && down > up ? source[up..down] : source;
}

static MigrationRisk ClassifyRisk(string upBody)
{
    var signals = new List<string>();
    if (Regex.IsMatch(upBody, @"\b(DropTable|DropColumn|RenameTable|RenameColumn)\s*\(")) signals.Add("destructive-or-rename-ddl");
    if (Regex.IsMatch(upBody, @"\bAlterColumn(?:<[^>]+>)?\s*\(")) signals.Add("alter-column-lock-and-conversion");
    if (Regex.IsMatch(upBody, @"\bCreateIndex\s*\(")) signals.Add("index-build-lock");
    if (Regex.IsMatch(upBody, @"\b(?:AddColumn(?:<[^>]+>)?|AddForeignKey)\s*\(")) signals.Add("schema-lock");
    if (Regex.IsMatch(upBody, @"\b(Sql|UpdateData|InsertData)\s*\(")) signals.Add("data-change-or-backfill");
    var level = signals.Contains("destructive-or-rename-ddl") || signals.Contains("alter-column-lock-and-conversion")
        ? "high"
        : signals.Count > 0 ? "medium" : "low";
    return new MigrationRisk(level, signals.Distinct().Order().ToArray());
}

static string ExtractDatabaseName(string value)
{
    var match = Regex.Match(value, @"(?i)(?:Database|Initial Catalog)\s*=\s*(?<database>[^;]+)");
    return match.Success ? match.Groups["database"].Value.Trim() : "<not-declared>";
}

static bool IsBuildOutput(string path) =>
    path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase) ||
    path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase);

static string Relative(string root, string path) => Path.GetRelativePath(root, path).Replace('\\', '/');

static string Sha256(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();

internal sealed record ModuleSpec(
    string Name,
    string Schema,
    string ConnectionKey,
    int Order,
    string MigrationsPath,
    string ContextPath,
    Func<DbContext> CreateContext);

internal sealed record ModuleInventory(
    string Module,
    int Order,
    string Schema,
    string DbContext,
    string MigrationAssembly,
    string ConnectionKey,
    string TargetHistory,
    string ContextSource,
    EntityInventory[] Entities,
    SequenceInventory[] Sequences,
    MigrationInventory[] Migrations,
    string[] SchemaViolations);

internal sealed record EntityInventory(
    string Entity,
    string? Table,
    string? Schema,
    bool Owned,
    string[] PrimaryKey,
    KeyInventory[] Keys,
    IndexInventory[] Indexes,
    ForeignKeyInventory[] ForeignKeys,
    CheckConstraintInventory[] CheckConstraints,
    ColumnInventory[] Columns);

internal sealed record KeyInventory(string? Name, string[] Properties, bool Primary);
internal sealed record IndexInventory(string? Name, string[] Properties, bool Unique);
internal sealed record ForeignKeyInventory(string? Name, string[] Properties, string? PrincipalSchema, string? PrincipalTable);
internal sealed record CheckConstraintInventory(string? Name, string? Sql);
internal sealed record ColumnInventory(string Name, string? Column, string? StoreType, bool Nullable);
internal sealed record SequenceInventory(string Name, string? Schema);
internal sealed record MigrationInventory(string MigrationId, string? ProductVersion, string Source, string SourceSha256, MigrationRisk Risk);
internal sealed record MigrationRisk(string Level, string[] Signals);
internal sealed record StaticScanReport(
    SourceFinding[] RawSqlFindings,
    SourceFinding[] SchemaQualifiedTableReferences,
    SourceFinding[] DatabaseObjectDefinitions,
    string[] CrossSchemaFindings);
internal sealed record SourceFinding(string Path, int Line, string Kind, string Excerpt);
internal sealed record ConnectionSurfaceReport(
    string[] RequiredModuleKeys,
    ConfigurationFile[] ConfigurationFiles,
    ComposeFile[] ComposeFiles,
    SourceFinding[] DefaultConnectionFallbacks,
    ExternalEvidenceGap EnvironmentIdentityAndPermissions,
    string CurrentIdentityBoundary);
internal sealed record ConfigurationFile(string Path, ConnectionSetting[] Entries);
internal sealed record ConnectionSetting(string Key, string State, string Database);
internal sealed record ComposeFile(string Path, ComposeConnection[] Entries);
internal sealed record ComposeConnection(string Key, string Database, bool UsesEnvironmentCredentials);
internal sealed record ExternalEvidenceGap(string Owner, string CollectionProcedure);
internal sealed record AuthLegacyReport(string[] LegacyIds, string WrongAlias, string CanonicalId);

internal sealed record Arguments(string Root, string Output, string ManifestOutput)
{
    public static Arguments Parse(string[] args)
    {
        string? root = null;
        var output = "docs/architecture/review/evidence/gates/G02/G02-database-inventory.json";
        var manifestOutput = "docs/architecture/review/evidence/gates/G02/G02-migration-manifest.json";
        for (var index = 0; index < args.Length; index++)
        {
            switch (args[index])
            {
                case "--root": root = args[++index]; break;
                case "--output": output = args[++index]; break;
                case "--manifest-output": manifestOutput = args[++index]; break;
                default: throw new ArgumentException($"Unknown argument '{args[index]}'.");
            }
        }

        root ??= FindRepositoryRoot(Environment.CurrentDirectory);
        return new Arguments(root, output, manifestOutput);
    }

    private static string FindRepositoryRoot(string start)
    {
        var directory = new DirectoryInfo(start);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? throw new InvalidOperationException("Could not locate IFX.sln.");
    }
}
