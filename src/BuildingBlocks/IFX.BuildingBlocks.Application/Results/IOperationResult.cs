namespace IFX.BuildingBlocks.Application.Results;

public interface IOperationResult
{
    bool IsSuccess { get; }

    OperationErrorCategory ErrorCategory { get; }
}

public enum OperationErrorCategory
{
    None = 0,
    Validation = 1,
    BusinessRule = 2,
    NotFound = 3,
    Conflict = 4,
    Forbidden = 5
}
