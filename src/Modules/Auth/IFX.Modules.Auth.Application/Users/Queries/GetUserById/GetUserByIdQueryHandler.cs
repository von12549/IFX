using AutoMapper;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Queries.GetUserById;

public class GetUserByIdQueryHandler : IRequestHandler<GetUserByIdQuery, Result<UserProfileDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetUserByIdQueryHandler> _logger;

    public GetUserByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<GetUserByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<UserProfileDto>> Handle(GetUserByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);

            if (user == null)
                return Result<UserProfileDto>.Failure("User not found");

            return Result<UserProfileDto>.Success(_mapper.Map<UserProfileDto>(user));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user {UserId}", request.UserId);
            return Result<UserProfileDto>.Failure("An error occurred while retrieving the user");
        }
    }
}
