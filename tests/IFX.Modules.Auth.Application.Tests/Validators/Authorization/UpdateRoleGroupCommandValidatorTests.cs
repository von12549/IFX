using FluentValidation.TestHelper;
using IFX.Modules.Auth.Application.Authorization.Commands.UpdateRoleGroup;

namespace IFX.Modules.Auth.Application.Tests.Validators.Authorization;

public class UpdateRoleGroupCommandValidatorTests
{
    private readonly UpdateRoleGroupCommandValidator _validator = new();

    private static UpdateRoleGroupCommand Valid() => new(Guid.NewGuid(), "PlatformAdmins", "Platform administrator group");

    [Fact]
    public async Task Validate_WithValidCommand_Succeeds()
    {
        var result = await _validator.TestValidateAsync(Valid());
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Validate_WithEmptyRoleGroupId_Fails()
    {
        var result = await _validator.TestValidateAsync(Valid() with { RoleGroupId = Guid.Empty });
        result.ShouldHaveValidationErrorFor(x => x.RoleGroupId);
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

    [Fact]
    public async Task Validate_WithNameAtMaxLength_Succeeds()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Name = new string('A', 100) });
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
