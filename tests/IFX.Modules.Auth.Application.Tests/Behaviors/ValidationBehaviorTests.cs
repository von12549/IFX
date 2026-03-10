using IFX.Modules.Auth.Application.Behaviors;
using IFX.Modules.Auth.Application.Common;
using FluentValidation;
using FluentValidation.Results;
using MediatR;

namespace IFX.Modules.Auth.Application.Tests.Behaviors;

public record TestCommand(string Value) : IRequest<Result<string>>;

public class ValidationBehaviorTests
{
    private readonly Mock<RequestHandlerDelegate<Result<string>>> _nextMock;

    public ValidationBehaviorTests()
    {
        _nextMock = new Mock<RequestHandlerDelegate<Result<string>>>();
        _nextMock.Setup(n => n()).ReturnsAsync(Result<string>.Success("Success"));
    }

    [Fact]
    public async Task Handle_WithNoValidators_CallsNext()
    {
        // Arrange
        var validators = Enumerable.Empty<IValidator<TestCommand>>();
        var behavior = new ValidationBehavior<TestCommand, Result<string>>(validators);
        var command = new TestCommand("test");

        // Act
        var result = await behavior.Handle(command, _nextMock.Object, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        _nextMock.Verify(n => n(), Times.Once);
    }

    [Fact]
    public async Task Handle_WithValidRequest_CallsNext()
    {
        // Arrange
        var validatorMock = new Mock<IValidator<TestCommand>>();
        validatorMock
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<TestCommand>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        var validators = new[] { validatorMock.Object };
        var behavior = new ValidationBehavior<TestCommand, Result<string>>(validators);
        var command = new TestCommand("test");

        // Act
        var result = await behavior.Handle(command, _nextMock.Object, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        _nextMock.Verify(n => n(), Times.Once);
    }

    [Fact]
    public async Task Handle_WithInvalidRequest_ThrowsValidationException()
    {
        // Arrange
        var failures = new List<ValidationFailure>
        {
            new("Value", "Value is required")
        };
        var validationResult = new ValidationResult(failures);

        var validatorMock = new Mock<IValidator<TestCommand>>();
        validatorMock
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<TestCommand>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(validationResult);

        var validators = new[] { validatorMock.Object };
        var behavior = new ValidationBehavior<TestCommand, Result<string>>(validators);
        var command = new TestCommand("test");

        // Act
        var act = () => behavior.Handle(command, _nextMock.Object, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ValidationException>()
            .Where(ex => ex.Errors.Any(e => e.ErrorMessage == "Value is required"));
        _nextMock.Verify(n => n(), Times.Never);
    }

    [Fact]
    public async Task Handle_WithMultipleValidators_AggregatesErrors()
    {
        // Arrange
        var validator1Mock = new Mock<IValidator<TestCommand>>();
        validator1Mock
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<TestCommand>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new[] { new ValidationFailure("Value", "Error 1") }));

        var validator2Mock = new Mock<IValidator<TestCommand>>();
        validator2Mock
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<TestCommand>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new[] { new ValidationFailure("Value", "Error 2") }));

        var validators = new[] { validator1Mock.Object, validator2Mock.Object };
        var behavior = new ValidationBehavior<TestCommand, Result<string>>(validators);
        var command = new TestCommand("test");

        // Act
        var act = () => behavior.Handle(command, _nextMock.Object, CancellationToken.None);

        // Assert
        var exception = await act.Should().ThrowAsync<ValidationException>();
        exception.Which.Errors.Should().HaveCount(2);
        exception.Which.Errors.Select(e => e.ErrorMessage).Should().Contain("Error 1");
        exception.Which.Errors.Select(e => e.ErrorMessage).Should().Contain("Error 2");
    }

    [Fact]
    public async Task Handle_WithMixedValidationResults_ThrowsForFailures()
    {
        // Arrange
        var passingValidator = new Mock<IValidator<TestCommand>>();
        passingValidator
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<TestCommand>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        var failingValidator = new Mock<IValidator<TestCommand>>();
        failingValidator
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<TestCommand>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new[] { new ValidationFailure("Value", "Validation failed") }));

        var validators = new[] { passingValidator.Object, failingValidator.Object };
        var behavior = new ValidationBehavior<TestCommand, Result<string>>(validators);
        var command = new TestCommand("test");

        // Act
        var act = () => behavior.Handle(command, _nextMock.Object, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ValidationException>();
        _nextMock.Verify(n => n(), Times.Never);
    }
}
