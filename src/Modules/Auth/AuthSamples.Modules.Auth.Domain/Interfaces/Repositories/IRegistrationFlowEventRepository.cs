using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

public interface IRegistrationFlowEventRepository
{
    Task AddAsync(RegistrationFlowEvent registrationEvent, CancellationToken cancellationToken = default);
    Task<RegistrationFlowEvent?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task UpdateAsync(RegistrationFlowEvent registrationEvent, CancellationToken cancellationToken = default);
}
