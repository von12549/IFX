using System.Data.Common;
using Microsoft.Extensions.Configuration;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Configuration;

public static class RequiredConnectionString
{
    public static string Get(IConfiguration configuration, string name)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        var value = configuration.GetConnectionString(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Required connection string '{name}' is missing or blank.");
        }

        try
        {
            var builder = new DbConnectionStringBuilder { ConnectionString = value };
            var hasServer = builder.ContainsKey("Server") || builder.ContainsKey("Data Source");
            var hasDatabase = builder.ContainsKey("Database") || builder.ContainsKey("Initial Catalog");
            if (!hasServer || !hasDatabase)
            {
                throw new ArgumentException("A server and database are required.");
            }
        }
        catch (ArgumentException)
        {
            throw new InvalidOperationException(
                $"Required connection string '{name}' is invalid.");
        }

        return value;
    }
}
