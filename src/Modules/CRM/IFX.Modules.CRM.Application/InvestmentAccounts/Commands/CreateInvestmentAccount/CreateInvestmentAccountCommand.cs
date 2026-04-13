using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.CreateInvestmentAccount;

public record CreateInvestmentAccountCommand(
    string AccountNumber,
    InvestmentAccountType AccountType,
    DateOnly? CertificateDate) : IRequest<Result<InvestmentAccountDto>>;
