using AutoMapper;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Events;
using IFX.Modules.Registry.Application.FundClasses.Commands.DeleteClass;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Ports.Authorization;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public sealed class DeleteClassCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundClassRepository> _classes = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorization = new();
    private readonly Mock<ICommittedEventBuffer> _buffer = new();
    private readonly Mock<ILogger<DeleteClassCommandHandler>> _logger = new();
    private readonly Guid _tenantId = Guid.NewGuid();

    [Fact]
    public async Task Closing_class_records_internal_fact_with_previous_and_new_status()
    {
        var fundClass = FundClass.Create(Guid.NewGuid(), _tenantId, "CLOSE", "Close", "AUD", NavFrequency.Daily);
        Setup(fundClass);
        ClassStatusChanged? recorded = null;
        _buffer.Setup(value => value.Add(It.IsAny<ClassStatusChanged>()))
            .Callback<ClassStatusChanged>(value => recorded = value);

        var result = await Handler().Handle(new DeleteClassCommand(fundClass.Id, fundClass.FundId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        fundClass.Status.Should().Be(ClassStatus.Closed);
        recorded.Should().Be(new ClassStatusChanged(fundClass.Id, fundClass.FundId, "Active", "Closed"));
    }

    [Fact]
    public async Task Missing_class_does_not_record_internal_fact()
    {
        Setup(null);

        var result = await Handler().Handle(new DeleteClassCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        _buffer.VerifyNoOtherCalls();
    }

    private void Setup(FundClass? fundClass)
    {
        _currentUser.SetupGet(value => value.TenantId).Returns(_tenantId);
        _unitOfWork.SetupGet(value => value.FundClasses).Returns(_classes.Object);
        _classes.Setup(value => value.GetByIdAsync(It.IsAny<Guid>(), _tenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(fundClass);
        _authorization.Setup(value => value.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _mapper.Setup(value => value.Map<FundClassDto>(It.IsAny<FundClass>())).Returns(new FundClassDto());
    }

    private DeleteClassCommandHandler Handler() => new(
        _unitOfWork.Object, _mapper.Object, _currentUser.Object,
        _authorization.Object, _buffer.Object, _logger.Object);
}
