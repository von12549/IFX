// Types are in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public interface IRegistrationFlowEventRepository
{
    Task AddAsync(RegistrationFlowEvent registrationEvent, CancellationToken cancellationToken = default);
    Task<RegistrationFlowEvent?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task UpdateAsync(RegistrationFlowEvent registrationEvent, CancellationToken cancellationToken = default);
}
