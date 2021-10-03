USE [Forecsys.Projects.GFCOSA.OKEY.V2.Prod.Backup]
GO

/****** Object:  Table [dbo].[LostSalesDays]    Script Date: 03.10.2021 22:52:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LostSalesDays](
	[LocationId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[Date] [date] NOT NULL,
	[HourCount] [int] NULL,
	[Quantity] [real] NULL,
	[Revenue] [real] NULL,
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
 CONSTRAINT [PK_dbo.LostSalesDays] PRIMARY KEY CLUSTERED 
(
	[Date] ASC,
	[LocationId] ASC,
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[LostSalesDays]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.LostSalesDays_dbo.Locations_LocationId] FOREIGN KEY([LocationId])
REFERENCES [dbo].[Locations] ([Id])
GO

ALTER TABLE [dbo].[LostSalesDays] CHECK CONSTRAINT [FK_dbo.LostSalesDays_dbo.Locations_LocationId]
GO

ALTER TABLE [dbo].[LostSalesDays]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.LostSalesDays_dbo.Products_ProductId] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
GO

ALTER TABLE [dbo].[LostSalesDays] CHECK CONSTRAINT [FK_dbo.LostSalesDays_dbo.Products_ProductId]
GO


