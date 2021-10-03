USE [Forecsys.Projects.GFCOSA.OKEY.V2.Prod.Backup]
GO

/****** Object:  Table [dbo].[LostSalesHours]    Script Date: 03.10.2021 22:40:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LostSalesHours](
	[LocationId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[Date] [smalldatetime] NOT NULL,
	[Quantity] [real] NULL,
	[Revenue] [real] NULL,
	[Reason] [tinyint] NULL,
 CONSTRAINT [PK_dbo.LostSalesHours] PRIMARY KEY CLUSTERED 
(
	[Date] ASC,
	[LocationId] ASC,
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80)
)
GO

ALTER TABLE [dbo].[LostSalesHours]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.LostSalesHours_dbo.Locations_LocationId] FOREIGN KEY([LocationId])
REFERENCES [dbo].[Locations] ([Id])
GO

ALTER TABLE [dbo].[LostSalesHours] CHECK CONSTRAINT [FK_dbo.LostSalesHours_dbo.Locations_LocationId]
GO

ALTER TABLE [dbo].[LostSalesHours]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.LostSalesHours_dbo.Products_ProductId] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
GO

ALTER TABLE [dbo].[LostSalesHours] CHECK CONSTRAINT [FK_dbo.LostSalesHours_dbo.Products_ProductId]
GO


