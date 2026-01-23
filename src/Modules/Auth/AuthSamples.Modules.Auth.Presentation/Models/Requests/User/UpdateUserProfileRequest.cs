using System.ComponentModel.DataAnnotations;

namespace AuthSamples.Modules.Auth.Presentation.Models.Requests.User;

public class UpdateUserProfileRequest
{
    [MinLength(3)]
    [MaxLength(50)]
    public string? Username { get; set; }

    [MaxLength(100)]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    public string? LastName { get; set; }

    [Phone]
    public string? PhoneNumber { get; set; }

    [EmailAddress]
    [MaxLength(255)]
    public string? Email { get; set; }
}
