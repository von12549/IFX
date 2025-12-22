using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class RegistrationFlowEventRepository : IRegistrationFlowEventRepository
{
    private readonly CognitoDbContext _context;

    public RegistrationFlowEventRepository(CognitoDbContext context)
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
