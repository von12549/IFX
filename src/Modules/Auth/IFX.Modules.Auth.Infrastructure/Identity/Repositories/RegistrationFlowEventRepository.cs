using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Identity;
// Repository interface is in IFX.Modules.Auth.Domain.Identity
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Identity.Repositories;

public class RegistrationFlowEventRepository : IRegistrationFlowEventRepository
{
    private readonly AuthDbContext _context;

    public RegistrationFlowEventRepository(AuthDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(RegistrationFlowEvent registrationEvent, CancellationToken cancellationToken = default)
    {
        await _context.RegistrationFlowEvents.AddAsync(registrationEvent, cancellationToken);
    }

    public async Task<RegistrationFlowEvent?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        return await _context.RegistrationFlowEvents
            .Where(rfe => rfe.Email == email.ToLowerInvariant())
            .OrderByDescending(rfe => rfe.RegistrationInitiatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public Task UpdateAsync(RegistrationFlowEvent registrationEvent, CancellationToken cancellationToken = default)
    {
        _context.RegistrationFlowEvents.Update(registrationEvent);
        return Task.CompletedTask;
    }
}
