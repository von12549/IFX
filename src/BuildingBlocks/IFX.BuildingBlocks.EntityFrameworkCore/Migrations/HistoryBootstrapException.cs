namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public sealed class HistoryBootstrapException : InvalidOperationException
{
    public HistoryBootstrapException(string message)
        : base(message)
    {
    }
}
