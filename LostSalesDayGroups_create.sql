USE [Forecsys.Projects.GFCOSA.OKEY.V2.Prod.Backup]
GO

/****** Object:  Table [dbo].[LostSalesDayGroups]    Script Date: 03.10.2021 22:53:21 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LostSalesDayGroups](
	[LocationId] [int] NOT NULL,
	[GroupId] [int] NOT NULL,
	[Date] [date] NOT NULL,
	[Quantity] [real] NULL,
	[Revenue] [real] NULL,
	[GroupLevel] [tinyint] NULL,
	[KviQuantity] [real] NULL,
	[KviRevenue] [real] NULL,
	[PromoQuantity] [real] NULL,
	[PromoRevenue] [real] NULL,
	[AutoOrderQuantity] [real] NULL,
	[AutoOrderRevenue] [real] NULL,
	[PlanningRegularProductQuantity] [real] NULL,
	[PlanningRegularProductRevenue] [real] NULL,
	[PlanningPromoProductQuantity] [real] NULL,
	[PlanningPromoProductRevenue] [real] NULL,
	[PlanningNewProductQuantity] [real] NULL,
	[PlanningNewProductRevenue] [real] NULL,
	[LogisticSupplierDeliveryDelayQuantity] [real] NULL,
	[LogisticSupplierDeliveryDelayRevenue] [real] NULL,
	[LogisticSupplierSmallDeliveryQuantity] [real] NULL,
	[LogisticSupplierSmallDeliveryRevenue] [real] NULL,
	[LogisticDcDeliveryDelayQuantity] [real] NULL,
	[LogisticDcDeliveryDelayRevenue] [real] NULL,
	[LogisticDcSmallDeliveryQuantity] [real] NULL,
	[LogisticDcSmallDeliveryRevenue] [real] NULL,
	[MerchandisingDisplayQuantity] [real] NULL,
	[MerchandisingDisplayRevenue] [real] NULL,
	[MerchandisingIncorrectStockQuantity] [real] NULL,
	[MerchandisingIncorrectStockRevenue] [real] NULL,
	[SignificantPromoQuantity] [real] NULL,
	[SignificantPromoRevenue] [real] NULL,
	[NonSignificantPromoQuantity] [real] NULL,
	[NonSignificantPromoRevenue] [real] NULL,
	[AbcCategory] [tinyint] NOT NULL,
 CONSTRAINT [PK_dbo.LostSalesDayGroups] PRIMARY KEY CLUSTERED 
(
	[Date] ASC,
	[GroupId] ASC,
	[LocationId] ASC,
	[AbcCategory] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[LostSalesDayGroups] ADD  DEFAULT ((0)) FOR [AbcCategory]
GO

ALTER TABLE [dbo].[LostSalesDayGroups]  WITH CHECK ADD  CONSTRAINT [FK_dbo.LostSalesDayGroups_dbo.Groups_GroupId] FOREIGN KEY([GroupId])
REFERENCES [dbo].[Groups] ([Id])
GO

ALTER TABLE [dbo].[LostSalesDayGroups] CHECK CONSTRAINT [FK_dbo.LostSalesDayGroups_dbo.Groups_GroupId]
GO

ALTER TABLE [dbo].[LostSalesDayGroups]  WITH CHECK ADD  CONSTRAINT [FK_dbo.LostSalesDayGroups_dbo.Locations_LocationId] FOREIGN KEY([LocationId])
REFERENCES [dbo].[Locations] ([Id])
GO

ALTER TABLE [dbo].[LostSalesDayGroups] CHECK CONSTRAINT [FK_dbo.LostSalesDayGroups_dbo.Locations_LocationId]
GO


