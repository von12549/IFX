namespace IFX.BuildingBlocks.Security.Authorization.Exceptions;

public class ForbiddenException : Exception
{
    public ForbiddenException(string message = "Access denied.") : base(message) { }
}
