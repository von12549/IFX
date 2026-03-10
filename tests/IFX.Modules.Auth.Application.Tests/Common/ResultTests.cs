using IFX.Modules.Auth.Application.Common;

namespace IFX.Modules.Auth.Application.Tests.Common;

public class ResultTests
{
    [Fact]
    public void Success_ReturnsSuccessResult()
    {
        // Act
        var result = Result<string>.Success("value");

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value.Should().Be("value");
        result.Error.Should().BeNull();
        result.Errors.Should().BeNull();
    }

    [Fact]
    public void Failure_WithSingleError_ReturnsFailureResult()
    {
        // Arrange
        var errorMessage = "Something went wrong";

        // Act
        var result = Result<string>.Failure(errorMessage);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Value.Should().BeNull();
        result.Error.Should().Be(errorMessage);
        result.Errors.Should().BeNull();
    }

    [Fact]
    public void Failure_WithMultipleErrors_ReturnsFailureResult()
    {
        // Arrange
        var errors = new List<string> { "Error 1", "Error 2", "Error 3" };

        // Act
        var result = Result<string>.Failure(errors);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Value.Should().BeNull();
        result.Error.Should().Be("Error 1");
        result.Errors.Should().HaveCount(3);
        result.Errors.Should().ContainInOrder("Error 1", "Error 2", "Error 3");
    }

    [Fact]
    public void Success_WithComplexType_ReturnsValue()
    {
        // Arrange
        var complexValue = new { Id = 1, Name = "Test" };

        // Act
        var result = Result<object>.Success(complexValue);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value.Should().Be(complexValue);
    }
}

public class PagedResultTests
{
    [Fact]
    public void TotalPages_CalculatesCorrectly()
    {
        // Arrange
        var pagedResult = new PagedResult<string>
        {
            TotalCount = 25,
            PageSize = 10
        };

        // Act & Assert
        pagedResult.TotalPages.Should().Be(3);
    }

    [Fact]
    public void TotalPages_WithExactDivision_CalculatesCorrectly()
    {
        // Arrange
        var pagedResult = new PagedResult<string>
        {
            TotalCount = 20,
            PageSize = 10
        };

        // Act & Assert
        pagedResult.TotalPages.Should().Be(2);
    }

    [Fact]
    public void HasPreviousPage_OnFirstPage_ReturnsFalse()
    {
        // Arrange
        var pagedResult = new PagedResult<string>
        {
            PageNumber = 1,
            TotalCount = 25,
            PageSize = 10
        };

        // Act & Assert
        pagedResult.HasPreviousPage.Should().BeFalse();
    }

    [Fact]
    public void HasPreviousPage_OnSecondPage_ReturnsTrue()
    {
        // Arrange
        var pagedResult = new PagedResult<string>
        {
            PageNumber = 2,
            TotalCount = 25,
            PageSize = 10
        };

        // Act & Assert
        pagedResult.HasPreviousPage.Should().BeTrue();
    }

    [Fact]
    public void HasNextPage_OnLastPage_ReturnsFalse()
    {
        // Arrange
        var pagedResult = new PagedResult<string>
        {
            PageNumber = 3,
            TotalCount = 25,
            PageSize = 10
        };

        // Act & Assert
        pagedResult.HasNextPage.Should().BeFalse();
    }

    [Fact]
    public void HasNextPage_NotOnLastPage_ReturnsTrue()
    {
        // Arrange
        var pagedResult = new PagedResult<string>
        {
            PageNumber = 1,
            TotalCount = 25,
            PageSize = 10
        };

        // Act & Assert
        pagedResult.HasNextPage.Should().BeTrue();
    }
}
