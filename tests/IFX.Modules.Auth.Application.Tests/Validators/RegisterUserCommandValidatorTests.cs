using IFX.Modules.Auth.Application.Identity.Commands.RegisterUser;
using IFX.Tests.Common;
using FluentValidation.TestHelper;

namespace IFX.Modules.Auth.Application.Tests.Validators;

public class RegisterUserCommandValidatorTests
{
    private readonly RegisterUserCommandValidator _validator;

    public RegisterUserCommandValidatorTests()
    {
        _validator = new RegisterUserCommandValidator();
    }

    private RegisterUserCommand CreateValidCommand() => new(
        Email: TestConstants.ValidEmail,
        Password: TestConstants.ValidPassword,
        Username: "testuser",
        FirstName: TestConstants.ValidFirstName,
        LastName: TestConstants.ValidLastName,
        BirthDate: TestConstants.ValidBirthDate,
        PhoneNumber: TestConstants.ValidPhoneNumber,
        IpAddress: TestConstants.ValidIpAddress);

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
    public async Task Validate_WithShortPassword_FailsWithMessage()
    {
        // Arrange
        var command = CreateValidCommand() with { Password = "Abc@1" };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Password)
            .WithErrorMessage("Password must be at least 8 characters");
    }

    [Fact]
    public async Task Validate_WithPasswordMissingUppercase_FailsWithMessage()
    {
        // Arrange
        var command = CreateValidCommand() with { Password = "test@12345" };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Password)
            .WithErrorMessage("Password must contain uppercase letter");
    }

    [Fact]
    public async Task Validate_WithPasswordMissingLowercase_FailsWithMessage()
    {
        // Arrange
        var command = CreateValidCommand() with { Password = "TEST@12345" };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Password)
            .WithErrorMessage("Password must contain lowercase letter");
    }

    [Fact]
    public async Task Validate_WithPasswordMissingNumber_FailsWithMessage()
    {
        // Arrange
        var command = CreateValidCommand() with { Password = "TestPassword@" };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Password)
            .WithErrorMessage("Password must contain number");
    }

    [Fact]
    public async Task Validate_WithPasswordMissingSpecialChar_FailsWithMessage()
    {
        // Arrange
        var command = CreateValidCommand() with { Password = "TestPassword123" };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Password)
            .WithErrorMessage("Password must contain special character");
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyUsername_FailsWithMessage(string? username)
    {
        // Arrange
        var command = CreateValidCommand() with { Username = username! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Username)
            .WithErrorMessage("Username is required");
    }

    [Theory]
    [InlineData("ab")]
    public async Task Validate_WithShortUsername_Fails(string username)
    {
        // Arrange
        var command = CreateValidCommand() with { Username = username };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Username);
    }

    [Theory]
    [InlineData("user name")]
    [InlineData("user@name")]
    [InlineData("user.name")]
    public async Task Validate_WithInvalidUsernameChars_FailsWithMessage(string username)
    {
        // Arrange
        var command = CreateValidCommand() with { Username = username };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.Username)
            .WithErrorMessage("Username can only contain letters, numbers, hyphens, and underscores");
    }

    [Theory]
    [InlineData("user_name")]
    [InlineData("user-name")]
    [InlineData("userName123")]
    public async Task Validate_WithValidUsername_Succeeds(string username)
    {
        // Arrange
        var command = CreateValidCommand() with { Username = username };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.Username);
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyFirstName_FailsWithMessage(string? firstName)
    {
        // Arrange
        var command = CreateValidCommand() with { FirstName = firstName! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.FirstName)
            .WithErrorMessage("First name is required");
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyLastName_FailsWithMessage(string? lastName)
    {
        // Arrange
        var command = CreateValidCommand() with { LastName = lastName! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.LastName)
            .WithErrorMessage("Last name is required");
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyBirthDate_FailsWithMessage(string? birthDate)
    {
        // Arrange
        var command = CreateValidCommand() with { BirthDate = birthDate! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.BirthDate)
            .WithErrorMessage("Birth date is required");
    }

    [Theory]
    [InlineData("01-15-1990")]
    [InlineData("1990/01/15")]
    [InlineData("15-01-1990")]
    public async Task Validate_WithInvalidBirthDateFormat_FailsWithMessage(string birthDate)
    {
        // Arrange
        var command = CreateValidCommand() with { BirthDate = birthDate };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.BirthDate)
            .WithErrorMessage("Birth date must be in YYYY-MM-DD format");
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task Validate_WithEmptyPhoneNumber_FailsWithMessage(string? phoneNumber)
    {
        // Arrange
        var command = CreateValidCommand() with { PhoneNumber = phoneNumber! };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.PhoneNumber)
            .WithErrorMessage("Phone number is required");
    }

    [Theory]
    [InlineData("1234567890")]
    [InlineData("(123) 456-7890")]
    [InlineData("+0123456789")]
    public async Task Validate_WithInvalidPhoneNumberFormat_FailsWithMessage(string phoneNumber)
    {
        // Arrange
        var command = CreateValidCommand() with { PhoneNumber = phoneNumber };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.PhoneNumber)
            .WithErrorMessage("Phone number must be in E.164 format (+1234567890)");
    }

    [Theory]
    [InlineData("+61412345678")]
    [InlineData("+12025551234")]
    [InlineData("+447911123456")]
    public async Task Validate_WithValidPhoneNumber_Succeeds(string phoneNumber)
    {
        // Arrange
        var command = CreateValidCommand() with { PhoneNumber = phoneNumber };

        // Act
        var result = await _validator.TestValidateAsync(command);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.PhoneNumber);
    }
}
