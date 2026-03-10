using IFX.Modules.Auth.Domain.ValueObjects;
using IFX.Tests.Common;

namespace IFX.Modules.Auth.Domain.Tests.ValueObjects;

public class SubjectTests
{
    [Theory]
    [InlineData("a1b2c3d4-e5f6-7890-abcd-ef1234567890")]
    [InlineData("user-subject-123")]
    [InlineData("google-oauth2|123456789")]
    public void Create_WithValidSubject_ReturnsSubject(string subject)
    {
        // Act
        var result = Subject.Create(subject);

        // Assert
        result.Should().NotBeNull();
        result.Value.Should().Be(subject);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Create_WithEmptyValue_ThrowsArgumentException(string? value)
    {
        // Act
        var act = () => Subject.Create(value!);

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*cannot be empty*");
    }

    [Fact]
    public void Equals_SameSubject_ReturnsTrue()
    {
        // Arrange
        var subject1 = Subject.Create("test-subject-123");
        var subject2 = Subject.Create("test-subject-123");

        // Act & Assert
        subject1.Equals(subject2).Should().BeTrue();
        (subject1 == subject2).Should().BeTrue();
        (subject1 != subject2).Should().BeFalse();
    }

    [Fact]
    public void Equals_DifferentSubject_ReturnsFalse()
    {
        // Arrange
        var subject1 = Subject.Create("subject-1");
        var subject2 = Subject.Create("subject-2");

        // Act & Assert
        subject1.Equals(subject2).Should().BeFalse();
        (subject1 == subject2).Should().BeFalse();
        (subject1 != subject2).Should().BeTrue();
    }

    [Fact]
    public void Equals_WithNull_ReturnsFalse()
    {
        // Arrange
        var subject = Subject.Create("test-subject");

        // Act & Assert
        subject.Equals(null).Should().BeFalse();
        (subject == null).Should().BeFalse();
    }

    [Fact]
    public void GetHashCode_SameSubject_ReturnsSameHashCode()
    {
        // Arrange
        var subject1 = Subject.Create("test-subject");
        var subject2 = Subject.Create("test-subject");

        // Act & Assert
        subject1.GetHashCode().Should().Be(subject2.GetHashCode());
    }

    [Fact]
    public void ToString_ReturnsSubjectValue()
    {
        // Arrange
        var subjectValue = "test-subject-123";
        var subject = Subject.Create(subjectValue);

        // Act & Assert
        subject.ToString().Should().Be(subjectValue);
    }
}
