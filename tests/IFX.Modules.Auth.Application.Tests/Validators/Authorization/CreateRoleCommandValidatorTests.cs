using FluentValidation.TestHelper;
using IFX.Modules.Auth.Application.Authorization.Commands.CreateRole;

namespace IFX.Modules.Auth.Application.Tests.Validators.Authorization;

public class CreateRoleCommandValidatorTests
{
    private readonly CreateRoleCommandValidator _validator = new();

    private static CreateRoleCommand Valid() => new("ValidRole", "A valid role description", Guid.NewGuid());

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
    public async Task Validate_WithNameTooShort_Fails()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = "ab" });
        result.ShouldHaveValidationErrorFor(x => x.Name);
    }

    [Fact]
    public async Task Validate_WithNameTooLong_Fails()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = new string('A', 51) });
        result.ShouldHaveValidationErrorFor(x => x.Name);
    }

    [Theory]
    [InlineData("Role Name")]    // space not allowed
    [InlineData("Role!")]        // special char
    [InlineData("Role.Read")]    // dot not allowed
    public async Task Validate_WithInvalidNameChars_Fails(string name)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = name });
        result.ShouldHaveValidationErrorFor(x => x.Name);
    }

    [Theory]
    [InlineData("ValidRole")]
    [InlineData("Role-123")]
    [InlineData("Role_Name")]
    public async Task Validate_WithValidNameChars_Succeeds(string name)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = name });
        result.ShouldNotHaveValidationErrorFor(x => x.Name);
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
