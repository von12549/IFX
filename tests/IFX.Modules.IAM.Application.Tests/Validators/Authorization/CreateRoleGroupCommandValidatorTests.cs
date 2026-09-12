using FluentValidation.TestHelper;
using IFX.Modules.IAM.Application.Access.RoleGroups.Commands.CreateRoleGroup;

namespace IFX.Modules.IAM.Application.Tests.Validators.Authorization;

public class CreateRoleGroupCommandValidatorTests
{
    private readonly CreateRoleGroupCommandValidator _validator = new();

    private static CreateRoleGroupCommand Valid() => new("Managers", "Management group", Guid.NewGuid());

    [Fact]
    public async Task Validate_WithValidCommand_Succeeds()
    {
        var result = await _validator.TestValidateAsync(Valid());
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyName_Fails(string? name)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = name! });
        result.ShouldHaveValidationErrorFor(x => x.Name);
    }

    [Fact]
    public async Task Validate_WithNameTooLong_Fails()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = new string('A', 101) });
        result.ShouldHaveValidationErrorFor(x => x.Name);
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyDescription_Fails(string? desc)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Description = desc! });
        result.ShouldHaveValidationErrorFor(x => x.Description);
    }

    [Fact]
    public async Task Validate_WithDescriptionTooLong_Fails()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Description = new string('A', 256) });
        result.ShouldHaveValidationErrorFor(x => x.Description);
    }
}
