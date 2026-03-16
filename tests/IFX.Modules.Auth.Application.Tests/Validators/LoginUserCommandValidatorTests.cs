using IFX.Modules.Auth.Application.Identity.Commands.LoginUser;
using IFX.Tests.Common;
using FluentValidation.TestHelper;

namespace IFX.Modules.Auth.Application.Tests.Validators;

public class LoginUserCommandValidatorTests
{
    private readonly LoginUserCommandValidator _validator;

    public LoginUserCommandValidatorTests()
    {
        _validator = new LoginUserCommandValidator();
    }

    private LoginUserCommand CreateValidCommand() => new(
        Email: TestConstants.ValidEmail,
        Password: TestConstants.ValidPassword,
        IpAddress: TestConstants.ValidIpAddress,
        UserAgent: TestConstants.ValidUserAgent);

    [Fact]
    public async Task Validate_WithValidCommand_Succeeds()
    {
        // Arrange
        var command = CreateValidCommand();

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyEmail_FailsWithMessage(string? email)
    {
        // Arrange
        var command = CreateValidCommand() with { Email = email! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Email)
            .WithErrorMessage("Email is required");
    }

    [Theory]
    [InlineData("invalid")]
    [InlineData("@domain.com")]
    [InlineData("user@")]
    public async Task Validate_WithInvalidEmailFormat_FailsWithMessage(string email)
    {
        // Arrange
        var command = CreateValidCommand() with { Email = email };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Email)
            .WithErrorMessage("Invalid email format");
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyPassword_FailsWithMessage(string? password)
    {
        // Arrange
        var command = CreateValidCommand() with { Password = password! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Password)
            .WithErrorMessage("Password is required");
    }

    [Fact]
    public async Task Validate_WithValidCredentials_Succeeds()
    {
        // Arrange
        var command = new LoginUserCommand(
            Email: "user@example.com",
            Password: "anypassword",
            IpAddress: "192.168.1.1",
            UserAgent: "Mozilla/5.0");

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldNotHaveAnyValidationErrors();
    }
}
