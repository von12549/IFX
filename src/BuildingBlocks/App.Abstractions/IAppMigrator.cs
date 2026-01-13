namespace App.Abstractions
{
    public interface IAppMigrator
    {
        Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default);
        string Name { get; }
    }
}
