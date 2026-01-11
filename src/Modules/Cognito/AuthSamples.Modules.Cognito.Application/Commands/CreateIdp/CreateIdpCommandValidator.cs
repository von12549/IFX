using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.CreateIdp;

public class CreateIdpCommandValidator : AbstractValidator<CreateIdpCommand>
{
    public CreateIdpCommandValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MaximumLength(100);

        RuleFor(x => x.Issuer)
            .NotEmpty().WithMessage("Issuer is required")
            .MaximumLength(500)
            .Must(BeValidUrl).WithMessage("Issuer must be a valid URL");

        RuleFor(x => x.Authority)
            .NotEmpty().WithMessage("Authority is required")
            .MaximumLength(500)
            .Must(BeValidUrl).WithMessage("Authority must be a valid URL");

        RuleFor(x => x.Description)
            .MaximumLength(1000);

        RuleFor(x => x.LoginUrl)
            .MaximumLength(500);

        RuleFor(x => x.ExpectedAudiences)
            .Must(BeValidJson).WithMessage("ExpectedAudiences must be valid JSON");

        RuleFor(x => x.AllowedAlgs)
            .Must(BeValidJson).WithMessage("AllowedAlgs must be valid JSON");

        RuleFor(x => x.RequiredScopes)
            .Must(BeValidJson).WithMessage("RequiredScopes must be valid JSON");

        RuleFor(x => x.ClaimMapping)
            .Must(BeValidJson).WithMessage("ClaimMapping must be valid JSON");

        RuleFor(x => x.ClockSkewSeconds)
            .GreaterThanOrEqualTo(0).WithMessage("ClockSkewSeconds must be non-negative")
            .LessThanOrEqualTo(3600).WithMessage("ClockSkewSeconds cannot exceed 1 hour (3600 seconds)");
    }

    private bool BeValidUrl(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return false;
        return Uri.TryCreate(url, UriKind.Absolute, out _);
    }

    private bool BeValidJson(string json)
    {
        if (string.IsNullOrWhiteSpace(json)) return true; // Allow empty
        try
        {
            System.Text.Json.JsonDocument.Parse(json);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
