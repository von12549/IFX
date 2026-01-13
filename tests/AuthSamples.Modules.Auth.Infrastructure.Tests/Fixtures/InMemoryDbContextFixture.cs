using AuthSamples.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Auth.Infrastructure.Tests.Fixtures;

public class InMemoryDbContextFixture : IDisposable
{
    public AuthDbContext Context { get; }

    public InMemoryDbContextFixture()
    {
        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        Context = new AuthDbContext(options);
        Context.Database.EnsureCreated();
    }

    public void Dispose()
    {
        Context.Database.EnsureDeleted();
        Context.Dispose();
    }
}
