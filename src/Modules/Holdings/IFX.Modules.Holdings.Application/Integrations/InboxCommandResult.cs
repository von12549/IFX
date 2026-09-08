using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Results;

namespace IFX.Modules.Holdings.Application.Integrations;

public sealed record InboxCommandResult(bool IsSuccess, OperationErrorCategory ErrorCategory, bool WasDuplicate) :
    IOperationResult,
    IInboxOperationResult
{
    public static InboxCommandResult Applied() => new(true, OperationErrorCategory.None, false);
    public static InboxCommandResult Duplicate() => new(true, OperationErrorCategory.None, true);
    public static InboxCommandResult Rejected() => new(false, OperationErrorCategory.BusinessRule, false);
}
