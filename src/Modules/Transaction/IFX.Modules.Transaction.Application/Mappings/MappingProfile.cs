using AutoMapper;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Domain.Entities;
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

        CreateMap<TxEntity, OrderLegDto>()
            .ForMember(d => d.TransactionId, o => o.MapFrom(s => s.Id))
            .ForMember(d => d.LegId, o => o.MapFrom(s => s.LegId ?? string.Empty))
            .ForMember(d => d.TransactionType, o => o.MapFrom(s => s.Type.ToString()))
            .ForMember(d => d.PriceType, o => o.MapFrom(s => s.DealingPriceDetails != null ? s.DealingPriceDetails.PriceType : null))
            .ForMember(d => d.TradeDate, o => o.MapFrom(s => s.TradeDate.ToString("yyyy-MM-dd")))
            .ForMember(d => d.SettlementDate, o => o.MapFrom(s => s.SettlementDate.HasValue ? s.SettlementDate.Value.ToString("yyyy-MM-dd") : null))
            .ForMember(d => d.Status, o => o.MapFrom(s => s.Status.ToString()));

        CreateMap<Order, OrderDto>()
            .ForMember(d => d.OrderId, o => o.MapFrom(s => s.Id))
            .ForMember(d => d.OrderType, o => o.MapFrom(s => s.OrderType.ToString()))
            .ForMember(d => d.Status, o => o.MapFrom(s => s.Status.ToString()))
            .ForMember(d => d.ExpectedTradeDate, o => o.MapFrom(s => s.ExpectedTradeDate.HasValue ? s.ExpectedTradeDate.Value.ToString("yyyy-MM-dd") : null))
            .ForMember(d => d.ExpectedSettlementDate, o => o.MapFrom(s => s.ExpectedSettlementDate.HasValue ? s.ExpectedSettlementDate.Value.ToString("yyyy-MM-dd") : null))
            .ForMember(d => d.Legs, o => o.MapFrom(s => s.Legs));

        CreateMap<Order, OrderSummaryDto>()
            .ForMember(d => d.OrderId, o => o.MapFrom(s => s.Id))
            .ForMember(d => d.OrderType, o => o.MapFrom(s => s.OrderType.ToString()))
            .ForMember(d => d.Status, o => o.MapFrom(s => s.Status.ToString()))
            .ForMember(d => d.LegCount, o => o.MapFrom(s => s.Legs.Count));
    }
}
