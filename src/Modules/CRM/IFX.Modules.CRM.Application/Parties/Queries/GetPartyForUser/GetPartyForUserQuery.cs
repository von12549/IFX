using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyForUser;

public record GetPartyForUserQuery(Guid UserId) : IRequest<Result<Guid?>>;
