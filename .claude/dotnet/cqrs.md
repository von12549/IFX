# CQRS with MediatR

## Purpose
Command/Query patterns and how to add new operations.

---

## Pattern Overview

- **Commands**: Modify state, wrapped in transactions
- **Queries**: Read data, use AsNoTracking()
- **Handlers**: One per command/query
- **Validators**: FluentValidation, auto-registered
- **Behaviors**: Cross-cutting pipeline (validation, logging, transactions)

---

## Add New Command

1. Create command record:
```csharp
// Commands/DoSomething/DoSomethingCommand.cs
public record DoSomethingCommand(
    string Param1,
    int Param2
) : IRequest<Result<DoSomethingDto>>;
```

2. Create handler:
```csharp
// Commands/DoSomething/DoSomethingCommandHandler.cs
public class DoSomethingCommandHandler : IRequestHandler<DoSomethingCommand, Result<DoSomethingDto>>
{
    public async Task<Result<DoSomethingDto>> Handle(
        DoSomethingCommand request,
        CancellationToken cancellationToken)
    {
        // Implementation
        return Result<DoSomethingDto>.Success(dto);
    }
}
```

3. Create validator:
```csharp
// Commands/DoSomething/DoSomethingCommandValidator.cs
public class DoSomethingCommandValidator : AbstractValidator<DoSomethingCommand>
{
    public DoSomethingCommandValidator()
    {
        RuleFor(x => x.Param1).NotEmpty();
        RuleFor(x => x.Param2).GreaterThan(0);
    }
}
```

4. Auto-registered via assembly scanning - no manual registration needed.

---

## Add New Query

1. Create query record:
```csharp
// Queries/GetSomething/GetSomethingQuery.cs
public record GetSomethingQuery(
    Guid Id
) : IRequest<Result<SomethingDto>>;
```

2. Create handler:
```csharp
// Queries/GetSomething/GetSomethingQueryHandler.cs
public class GetSomethingQueryHandler : IRequestHandler<GetSomethingQuery, Result<SomethingDto>>
{
    public async Task<Result<SomethingDto>> Handle(
        GetSomethingQuery request,
        CancellationToken cancellationToken)
    {
        // Use AsNoTracking() for read operations
        var entity = await _context.Entities
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == request.Id);

        return Result<SomethingDto>.Success(_mapper.Map<SomethingDto>(entity));
    }
}
```

---

## Pipeline Behaviors

Registered in order:
1. **LoggingBehavior** - Logs request/response
2. **ValidationBehavior** - Runs FluentValidation, throws `ValidationException`
3. **TransactionBehavior** - Wraps commands in database transaction

---

## Result Pattern

```csharp
// Success
return Result<T>.Success(value);

// Failure
return Result<T>.Failure("Error message");

// Check in handler
if (!result.IsSuccess)
{
    return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
}
```

---

## Endpoint to Handler

```csharp
public static async Task<IResult> DoSomething(
    [FromBody] DoSomethingRequest request,
    [FromServices] IMediator mediator)
{
    var command = new DoSomethingCommand(request.Param1, request.Param2);
    var result = await mediator.Send(command);

    if (!result.IsSuccess)
        return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

    return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value));
}
```
