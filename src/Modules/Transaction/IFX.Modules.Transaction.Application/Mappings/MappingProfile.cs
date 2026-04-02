using AutoMapper;
using IFX.Modules.Transaction.Application.DTOs;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<TxEntity, TransactionDto>()
            .ForMember(d => d.TransactionId, o => o.MapFrom(s => s.Id))
            .ForMember(d => d.Type, o => o.MapFrom(s => s.Type.ToString()))
            .ForMember(d => d.TradeDate, o => o.MapFrom(s => s.TradeDate.ToString("yyyy-MM-dd")))
            .ForMember(d => d.SettlementDate, o => o.MapFrom(s => s.SettlementDate.HasValue ? s.SettlementDate.Value.ToString("yyyy-MM-dd") : null))
            .ForMember(d => d.Status, o => o.MapFrom(s => s.Status.ToString()));
    }
}
