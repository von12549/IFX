using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyRoles;

public record GetPartyRolesQuery(Guid PartyId) : IRequest<Result<IReadOnlyList<PartyFunctionalRole>>>;
