using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Access.Abac.Templates;
using IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;

namespace IFX.Modules.IAM.Application.Tests.Validators.Authorization.Policies;

public class CreatePolicyCommandValidatorTests
{
    private readonly CreatePolicyCommandValidator _validator;

    public CreatePolicyCommandValidatorTests()
    {
        var registry = new AbacTemplateRegistry();
        registry.Register(new ConditionTemplate { Name = "SameTenant" });
        registry.Register(new ConditionTemplate { Name = "CreatedByMe" });

        _validator = new CreatePolicyCommandValidator(registry);
    }

    private static CreatePolicyCommand ValidCommand(
        Guid? tenantId = null,
        string name = "Read Own Profile",
        string resourceType = "user",
        string action = "read",
        List<PolicyConditionDto>? conditions = null)
    {
        return new CreatePolicyCommand(
            PolicyScope.Tenant,
            tenantId ?? Guid.NewGuid(),
            name,
            null,
            resourceType,
            action,
            conditions ?? [new PolicyConditionDto("SameTenant", null)]);
    }

    [Fact]
    public async Task Validate_WithValidCommand_Passes()
    {
        var result = await _validator.ValidateAsync(ValidCommand());
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public async Task Validate_WithEmptyTenantId_Fails()
    {
        var result = await _validator.ValidateAsync(ValidCommand(tenantId: Guid.Empty));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "TenantId");
    }

    [Fact]
    public async Task Validate_WithEmptyName_Fails()
    {
        var result = await _validator.ValidateAsync(ValidCommand(name: ""));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public async Task Validate_WithNameExceeding200Chars_Fails()
    {
        var result = await _validator.ValidateAsync(ValidCommand(name: new string('x', 201)));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public async Task Validate_WithEmptyConditions_Fails()
    {
        var result = await _validator.ValidateAsync(ValidCommand(conditions: []));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Conditions");
    }

    [Fact]
    public async Task Validate_WithUnknownTemplateName_Fails()
    {
        var conditions = new List<PolicyConditionDto> { new("UnknownTemplate", null) };
        var result = await _validator.ValidateAsync(ValidCommand(conditions: conditions));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("UnknownTemplate"));
    }

    [Fact]
    public async Task Validate_WithEmptyResourceType_Fails()
    {
        var result = await _validator.ValidateAsync(ValidCommand(resourceType: ""));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "ResourceType");
    }
}
