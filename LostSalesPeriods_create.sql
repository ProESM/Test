USE [Forecsys.Projects.GFCOSA.OKEY.V2.Prod.Backup]
GO

/****** Object:  Table [dbo].[LostSalesPeriods]    Script Date: 03.10.2021 22:42:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LostSalesPeriods](
	[LocationId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[DateStart] [smalldatetime] NOT NULL,
	[DateEnd] [smalldatetime] NOT NULL,
	[HoursCount] [int] NOT NULL,
	[Quantity] [real] NULL,
	[Revenue] [real] NULL,
	[Reason] [tinyint] NULL,
 CONSTRAINT [PK_dbo.LostSalesPeriods] PRIMARY KEY CLUSTERED 
(
	[DateStart] ASC,
	[LocationId] ASC,
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[LostSalesPeriods]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.LostSalesPeriods_dbo.Locations_LocationId] FOREIGN KEY([LocationId])
REFERENCES [dbo].[Locations] ([Id])
GO

ALTER TABLE [dbo].[LostSalesPeriods] CHECK CONSTRAINT [FK_dbo.LostSalesPeriods_dbo.Locations_LocationId]
GO

ALTER TABLE [dbo].[LostSalesPeriods]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.LostSalesPeriods_dbo.Products_ProductId] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
GO

ALTER TABLE [dbo].[LostSalesPeriods] CHECK CONSTRAINT [FK_dbo.LostSalesPeriods_dbo.Products_ProductId]
GO


