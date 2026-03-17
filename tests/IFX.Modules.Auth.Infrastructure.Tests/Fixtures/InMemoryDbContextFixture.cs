using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Tests.Fixtures;

public class InMemoryDbContextFixture : IDisposable
{
    public IfxDbContext Context { get; }

    public InMemoryDbContextFixture()
    {
        var options = new DbContextOptionsBuilder<IfxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        Context = new IfxDbContext(options);
        Context.Database.EnsureCreated();
    }

    public void Dispose()
    {
        Context.Database.EnsureDeleted();
        Context.Dispose();
    }
}
