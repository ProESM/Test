USE [GFC.Projects.OSA.Online.Okey]
GO
/****** Object:  StoredProcedure [dbo].[JobResultProcceed]    Script Date: 04.10.2021 0:22:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[JobResultProcceed]
    @JobId BIGINT,
    @SubJobId BIGINT = NULL,
    @BatchId BIGINT = NULL,
    @SubBatchId BIGINT = NULL
AS
BEGIN

UPDATE [dbo].[LostSalesAnalysisJobs]
	SET [Status] = 4,
	FilledJobResults = GETDATE()
WHERE JobId = @JobId

UPDATE [mng].[Jobs]
	SET [Status] = 4
WHERE Id = @JobId

--Анализируемая дата
DECLARE @AnalizeDatetime DATETIME
SELECT @AnalizeDatetime = aj.AnalizeDatetime 
FROM [dbo].[LostSalesAnalysisJobs] aj
WHERE aj.JobId = @JobId

IF OBJECT_ID('tempdb..#ProductGroups') IS NOT NULL
    DROP TABLE #ProductGroups

	create table #ProductGroups
	(
		ProductId int,
		ProductName nvarchar(256),
		IsActive bit,
		GroupId4 int,
		GroupName4 nvarchar(256),
		GroupId3 int,
		GroupName3 nvarchar(256),
		GroupId2 int,
		GroupName2 nvarchar(256),
		GroupId1 int,
		GroupName1 nvarchar(256),
		GroupId0 int,
		GroupName0 nvarchar(256)
	)

	insert into #ProductGroups
	SELECT
	p.Id, 
	p.Name, 
	p.IsActive,
	g3.Id as g3_id, 
	g3.Name as g3_name,
	g2.Id as g2_id, 
	g2.Name as g2_name,
	g1.Id as g1_id, 
	g1.Name as g1_name,
	g0.Id as g0_id, 
	g0.Name as g0_name
	FROM
	Products p
	JOIN ProductGroups g3
	ON p.ProductGroupId = g3.Id
	JOIN ProductGroups g2
	ON g3.ParentId = g2.Id
	JOIN ProductGroups g1
	ON g2.ParentId = g1.Id
    JOIN ProductGroups g0
	ON g1.ParentId = g0.Id


	IF OBJECT_ID('tempdb..#tmp_table') IS NOT NULL
    DROP TABLE #tmp_table

	create table #tmp_table
	(
		LostSalesAnalysisTaskId int,
		coeff float
	)

	INSERT INTO #tmp_table (LostSalesAnalysisTaskId, coeff)
	SELECT srp.LostSalesAnalysisTaskId,
		CASE 
			WHEN lsp.DateStart IS NULL 
					AND sel.sm IS NOT NULL 
					AND sel.sm > 0 THEN
				srp.Quantity / sel.sm
			ELSE CAST(1 as float)
		END
	FROM [dbo].[LostSalesAnalysisResultPeriods] srp
		LEFT JOIN [dbo].LostSalesPeriods lsp
			ON lsp.DateStart = srp.StartDatetime
			AND lsp.LocationId = srp.LocationId
			AND lsp.ProductId = srp.ProductId			
		LEFT JOIN 
			(SELECT LostSalesAnalysisTaskId, SUM(Quantity) as sm
			 FROM LostSalesAnalysisResultHourlies
			 WHERE LostSalesAnalysisJobId = @JobId
			 AND CAST(Datetime as Date) = @AnalizeDatetime
			 GROUP BY LostSalesAnalysisTaskId
			) as sel
			ON sel.LostSalesAnalysisTaskId = srp.LostSalesAnalysisTaskId
	WHERE srp.LostSalesAnalysisJobId = @JobId

		DECLARE @analyzeDate date = CAST(@AnalizeDatetime AS date)


	INSERT INTO [LostSalesHours](LocationId, ProductId, Date, Quantity, Revenue)
	SELECT
		srh.LocationId,
		srh.ProductId,
		srh.DateTime,
		srh.Quantity,
		srh.Quantity * st.Price
	FROM
		[dbo].LostSalesAnalysisResultHourlies srh
		JOIN LostSalesAnalysisTasks st
			ON srh.LostSalesAnalysisTaskId = st.Id			
		LEFT JOIN #tmp_table tmp 
			ON tmp.LostSalesAnalysisTaskId = srh.LostSalesAnalysisTaskId
	WHERE 
		srh.IsPhantom = 1
		AND srh.LostSalesAnalysisJobId = @JobId
		AND srh.Quantity > 0
		-- [25.07]
		AND CAST(srh.Date as Date) = @AnalizeDatetime
		
	-- [LostSalesPeriods]

	UPDATE LostSalesPeriods
	SET 
		Quantity = srp.Quantity,
		DateEnd = srp.DateEnd,
		HoursCount = srp.HoursCount,
		Revenue = srp.Quantity*st.Price		
	FROM
		[dbo].LostSalesPeriods lsp
		JOIN [dbo].[LostSalesAnalysisResultPeriods] srp
			ON lsp.DateStart = srp.DateStart
			AND lsp.LocationId = srp.LocationId
			AND lsp.ProductId = srp.ProductId
		JOIN LostSalesAnalysisTasks st
			ON srp.LostSalesAnalysisTaskId = st.Id
	WHERE srp.LostSalesAnalysisJobId = @JobId
		AND srp.IsPhantom = 1
		AND srp.Quantity > 0	
	
	INSERT INTO LostSalesPeriods (LocationId, ProductId, DateStart, DateEnd, HoursCount, Quantity, Revenue)
	SELECT srp.LocationId, srp.ProductId, srp.StartDatetime, srp.EndDatetime, srp.HoursCount, srp.Quantity, srp.Quantity*st.Price
	FROM
		[dbo].LostSalesAnalysisResultPeriods srp
		LEFT JOIN [dbo].LostSalesPeriods lsp
			ON lsp.DateStart = srp.DateStart
			AND lsp.LocationId = srp.LocationId
			AND lsp.ProductId = srp.ProductId
			AND srp.LostSalesAnalysisJobId = @JobId		
		JOIN LostSalesAnalysisTasks st
			ON srp.LostSalesAnalysisTaskId = st.Id
	WHERE 
		lsp.LocationID is NULL
		AND srp.IsPhantom = 1
		AND srp.LostSalesAnalysisJobId = @JobId
		AND srp.Quantity > 0
		
	-- no update - just insert
		
	Declare @dt_renew date
	SELECT @dt_renew = 
		   @AnalizeDatetime
		
	-- LostSalesDaily

	DELETE FROM LostSalesDays
	WHERE LocationId IN (SELECT DISTINCT LocationId FROM LostSalesAnalysisResultPeriods WHERE LostSalesAnalysisJobId = @JobId AND IsPhantom = 1)
		AND [Date] >= @dt_renew

	INSERT INTO LostSalesDays([LocationId], [ProductId], [Date], [Quantity], [Revenue], [HourCount])
	SELECT [LocationId], [ProductId], CAST([Date] as Date), SUM([Quantity]), SUM([Revenue]), Count([LocationId])
	FROM [LostSalesHours] 
	WHERE 
		LocationId IN (SELECT DISTINCT LocationId FROM LostSalesAnalysisResultPeriods WHERE LostSalesAnalysisJobId = @JobId AND IsPhantom = 1)
		AND [Date] >= @dt_renew
	GROUP BY [LocationId], [ProductId], CAST([Date] as Date)		
	
	-- [LostSalesDayGroups] 
	
	DELETE FROM [LostSalesDayGroups]
	WHERE [Date] >= @dt_renew
	
	
	
	INSERT INTO [LostSalesDayGroups]
	([GroupId], [LocationId], [Date], [AbcCategory], [Quantity], [Revenue], 
	[KviQuantity], [KviRevenue], [PromoQuantity], [PromoRevenue], [AutoOrderQuantity], [AutoOrderRevenue],
	[SignificantPromoQuantity], [SignificantPromoRevenue], [NonSignificantPromoQuantity], [NonSignificantPromoRevenue],
	[GroupLevel])
    SELECT [PG].[GroupId3] AS [GroupId]
			,[PS].[LocationId]
			,[PS].[Date]
			,[AM].[AbcCategory]
			,SUM([PS].[Quantity]) as [Quantity]
			,SUM([PS].[Revenue]) as [Revenue]
			,SUM(CASE WHEN [AM].[IsKvi] = 1 THEN [Quantity] ELSE 0 END) AS [KviQuantity]
			,SUM(CASE WHEN [AM].[IsKvi] = 1 THEN [Revenue] ELSE 0 END) AS [KviRevenue]
			,SUM(CASE WHEN [AM].[IsPromo] = 1 THEN [Quantity] ELSE 0 END) AS [PromoQuantity]
			,SUM(CASE WHEN [AM].[IsPromo] = 1 THEN [Revenue] ELSE 0 END) AS [PromoRevenue]
			,SUM(CASE WHEN [AM].[IsAutoOrder] = 1 THEN [Quantity] ELSE 0 END) AS [AutoOrderQuantity]
			,SUM(CASE WHEN [AM].[IsAutoOrder] = 1 THEN [Revenue] ELSE 0 END) AS [AutoOrderRevenue]
			,SUM(CASE WHEN spr.LocationId IS NOT NULL THEN [Quantity] ELSE 0 END) AS [SignificantPromoQuantity]
			,SUM(CASE WHEN spr.LocationId IS NOT NULL THEN [Revenue] ELSE 0 END) AS [SignificantPromoRevenue]
			,SUM(CASE WHEN spr.LocationId IS NULL AND [AM].[IsPromo] = 1 THEN [Quantity] ELSE 0 END) AS [NonSignificantPromoQuantity]
			,SUM(CASE WHEN spr.LocationId IS NULL AND [AM].[IsPromo] = 1 THEN [Revenue] ELSE 0 END) AS [NonSignificantPromoRevenue]
			,3 AS [GroupLevel]
    FROM [dbo].LostSalesDays [PS]
        INNER JOIN #ProductGroups [PG] ON [PG].ProductId = [PS].ProductId    
		INNER JOIN [dbo].[AssortmentMatrix] [AM] ON [AM].[LocationId] = [PS].[LocationId] AND [AM].[ProductId] = [PS].[ProductId] AND [AM].[Date] = [PS].[Date]
		LEFT JOIN significantPromo spr
			ON spr.LocationId = [AM].LocationId
			AND spr.ProductId = [AM].ProductId
			AND spr.Date = [AM].Date
    WHERE [PS].[Date] >= @dt_renew
    GROUP BY [PG].[GroupId3], [PS].[LocationId], [PS].[Date], [AM].[AbcCategory]

	
	-- g2
	INSERT INTO [LostSalesDayGroups]
	([GroupId], [LocationId], [Date], [AbcCategory], [Quantity], [Revenue], 
	[KviQuantity], [KviRevenue], [PromoQuantity], [PromoRevenue], [AutoOrderQuantity], [AutoOrderRevenue],
	[SignificantPromoQuantity], [SignificantPromoRevenue], [NonSignificantPromoQuantity], [NonSignificantPromoRevenue],
	[GroupLevel])
    SELECT GroupId2
			,[LocationId]
			,[Date]
			,[AbcCategory]
			,SUM([Quantity]) as [Quantity]
			,SUM([Revenue]) as [Revenue]
			,SUM(ISNULL([KviQuantity], 0)) AS [KviQuantity]
			,SUM(ISNULL([KviRevenue], 0)) AS [KviRevenue]
			,SUM(ISNULL([PromoQuantity], 0)) AS [PromoQuantity]
			,SUM(ISNULL([PromoRevenue], 0)) AS [PromoRevenue]
			,SUM(ISNULL([AutoOrderQuantity], 0)) AS [AutoOrderQuantity]
			,SUM(ISNULL([AutoOrderRevenue], 0)) AS [AutoOrderRevenue]
			,SUM([SignificantPromoQuantity]) AS [SignificantPromoQuantity]
			,SUM([SignificantPromoRevenue]) AS [SignificantPromoRevenue]
			,SUM([NonSignificantPromoQuantity]) AS [NonSignificantPromoQuantity]
			,SUM([NonSignificantPromoRevenue]) AS [NonSignificantPromoRevenue]
			,2 AS [GroupLevel]
    FROM [dbo].[LostSalesDayGroups] lsds
        JOIN (SELECT DISTINCT GroupId3, GroupId2 FROM #ProductGroups) p ON p.GroupId3 = lsds.GroupId AND GroupLevel = 3
    WHERE [Date] >= @dt_renew
    GROUP BY GroupId2, lsds.LocationId, Date, AbcCategory
	
	-- g1
	INSERT INTO [LostSalesDayGroups]
	([GroupId], [LocationId], [Date], [AbcCategory], [Quantity], [Revenue],
	[KviQuantity], [KviRevenue], [PromoQuantity], [PromoRevenue], [AutoOrderQuantity], [AutoOrderRevenue],
	[SignificantPromoQuantity], [SignificantPromoRevenue], [NonSignificantPromoQuantity], [NonSignificantPromoRevenue],
	[GroupLevel])
    SELECT GroupId1
			,[LocationId]
			,[Date]
			,[AbcCategory]
			,SUM([Quantity]) as [Quantity]
			,SUM([Revenue]) as [Revenue]
			,SUM(ISNULL([KviQuantity], 0)) AS [KviQuantity]
			,SUM(ISNULL([KviRevenue], 0)) AS [KviRevenue]
			,SUM(ISNULL([PromoQuantity], 0)) AS [PromoQuantity]
			,SUM(ISNULL([PromoRevenue], 0)) AS [PromoRevenue]
			,SUM(ISNULL([AutoOrderQuantity], 0)) AS [AutoOrderQuantity]
			,SUM(ISNULL([AutoOrderRevenue], 0)) AS [AutoOrderRevenue]
			,SUM([SignificantPromoQuantity]) AS [SignificantPromoQuantity]
			,SUM([SignificantPromoRevenue]) AS [SignificantPromoRevenue]
			,SUM([NonSignificantPromoQuantity]) AS [NonSignificantPromoQuantity]
			,SUM([NonSignificantPromoRevenue]) AS [NonSignificantPromoRevenue]
			,1 AS [GroupLevel]
    FROM [dbo].[LostSalesDayGroups] lsds
        JOIN (SELECT DISTINCT GroupId2, GroupId1 FROM #ProductGroups) p ON p.GroupId2 = lsds.GroupId AND GroupLevel = 2
    WHERE [Date] >= @dt_renew
    GROUP BY GroupId1, lsds.LocationId, Date, AbcCategory		


IF(OBJECT_ID('tempdb..#Results') IS NOT NULL)
BEGIN
	DROP TABLE #Results
END

CREATE TABLE #Results (
	LostSalesAnalysisTaskId BIGINT NOT NULL PRIMARY KEY,
	LostSalesAnalysisJobId BIGINT NOT NULL,    
	LocationId INT NOT NULL,
	ProductId INT NOT NULL,
    StoreExternalId NVARCHAR(32) NOT NULL,
    ProductExternaId NVARCHAR(32) NOT NULL,
	SignalDateTime DATETIME NOT NULL,
	IsKvi BIT NOT NULL,
	IsPromo BIT NOT NULL,
	AbcCategory VARCHAR(1) NULL,
	LostSalesStartDateTime DATETIME NOT NULL,
	LostSalesQuantity REAL NOT NULL,
	LostSalesMoney REAL NOT NULL
)


;WITH 
ResultPeriods AS 
(
    SELECT 
            rp.LostSalesAnalysisTaskId
            , rp.LostSalesAnalysisJobId
            , rp.LocationId
            , rp.ProductId
            , l.ExternalId StoreExternalId
            , p.ExternalId ProductExternaId
            , MAX(rp.Created) AS SignalDateTime
            , t.IsKvi 
            , IIF(t.PromoAlgType = 0, 0, 1) AS IsPromo
            , t.AbcCategory
            , rp.[StartDatetime] AS LostSalesStartDateTime
            , SUM(rp.Quantity) AS LostSalesQuantity
            , SUM(rp.Quantity * t.Price) AS LostSalesMoney
            , rp.Probability 
			, t.PriceIncreased
        FROM [dbo].[LostSalesAnalysisResultPeriods] AS rp
        INNER JOIN [dbo].LostSalesAnalysisTasks AS t
            ON t.Id = rp.LostSalesAnalysisTaskId
            AND t.LostSalesAnalysisJobId = rp.LostSalesAnalysisJobId
        INNER JOIN [dbo].[Locations] AS l
            ON l.Id = rp.LocationId
        INNER JOIN [dbo].[Products] AS p
            ON p.Id = rp.ProductId
         WHERE rp.LostSalesAnalysisJobId = @JobId 
            AND (@SubJobId IS NULL OR t.LostSalesAnalysisSubJobId = @SubJobId)
            AND (@BatchId IS NULL OR t.LostSalesAnalysisBatchId = @BatchId)
            AND (@SubBatchId IS NULL OR t.LostSalesAnalysisSubBatchId = @SubBatchId)  
            AND rp.IsPhantom = 1 
        GROUP BY  rp.LostSalesAnalysisTaskId
            , rp.LostSalesAnalysisJobId
            , rp.LocationId
            , rp.ProductId
            , l.ExternalId
            , p.ExternalId
            , t.IsKvi 
            , IIF(t.PromoAlgType = 0, 0, 1) 
            , t.AbcCategory
            , t.Price
            , rp.[StartDatetime]
            , rp.Probability
			, t.PriceIncreased
)
INSERT INTO #Results(
LostSalesAnalysisJobId
    , LostSalesAnalysisTaskId
    , LocationId
    , ProductId
    , StoreExternalId
    , ProductExternaId
    , SignalDateTime
    , IsKvi
    , IsPromo
    , AbcCategory
    , LostSalesStartDateTime
    , LostSalesQuantity
    , LostSalesMoney
)
SELECT LostSalesAnalysisJobId
    , LostSalesAnalysisTaskId
    , LocationId
    , ProductId
    , StoreExternalId
    , ProductExternaId
    , SignalDateTime
    , IsKvi
    , IsPromo
    , AbcCategory
    , LostSalesStartDateTime
    , LostSalesQuantity
    , LostSalesMoney
FROM 
(
    SELECT LostSalesAnalysisJobId
        , LostSalesAnalysisTaskId
        , LocationId
        , ProductId
        , StoreExternalId
        , ProductExternaId
        , SignalDateTime
        , IsKvi
        , IsPromo
        , AbcCategory
        , LostSalesStartDateTime
        , LostSalesQuantity
        , LostSalesMoney
        , Rank() OVER (PARTITION BY rp.LocationId ORDER BY rp.PriceIncreased, rp.Probability DESC, rp.ProductId) AS Rank 
    FROM ResultPeriods rp
) AS rs 



UPDATE [dbo].[LostSalesAnalysisJobs]
	SET [Status] = 5,
	JobResultsProceed = GETDATE()
WHERE JobId = @JobId

UPDATE [mng].[Jobs]
	SET [Status] = 5,
	EndDate = GETDATE()
WHERE Id = @JobId


BEGIN TRY DROP TABLE #Results END TRY
BEGIN CATCH END CATCH

END
