using IFX.Modules.Auth.Domain.Common;
using IFX.Modules.Auth.Domain.Enums;

namespace IFX.Modules.Auth.Domain.Entities;

public class RegistrationFlowEvent : BaseEntity
{
    public string Email { get; private set; } = string.Empty;
    public string Username { get; private set; } = string.Empty;
    public DateTime RegistrationInitiatedAt { get; private set; }
    public DateTime? RegistrationConfirmedAt { get; private set; }
    public RegistrationStatus Status { get; private set; }
    public string? ConfirmationCode { get; private set; }
    public string? FailureReason { get; private set; }
    public string IpAddress { get; private set; } = string.Empty;
    public Guid? UserId { get; private set; }

    private RegistrationFlowEvent() { } // For EF Core

    public static RegistrationFlowEvent Create(
        string email,
        string username,
        string ipAddress)
    {
        return new RegistrationFlowEvent
        {
            Email = email,
            Username = username,
            RegistrationInitiatedAt = DateTime.UtcNow,
            RegistrationConfirmedAt = null,
            Status = RegistrationStatus.Initiated,
            ConfirmationCode = null,
            FailureReason = null,
            IpAddress = ipAddress,
            UserId = null
        };
    }

    public void Confirm(Guid userId)
    {
        Status = RegistrationStatus.Confirmed;
        RegistrationConfirmedAt = DateTime.UtcNow;
        UserId = userId;
    }

    public void MarkAsFailed(string failureReason)
    {
        Status = RegistrationStatus.Failed;
        FailureReason = failureReason;
    }

    public void MarkAsExpired()
    {
        Status = RegistrationStatus.Expired;
    }
}
