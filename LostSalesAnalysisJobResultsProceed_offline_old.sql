USE [Forecsys.Projects.GFCOSA.OKEY.V2.Prod.Backup]
GO
/****** Object:  StoredProcedure [dbo].[LostSalesAnalysisJobResultsProceed]    Script Date: 25.09.2021 23:50:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[LostSalesAnalysisJobResultsProceed]
	@JobId int
AS
BEGIN

	DECLARE @Probability float
	SET @Probability = 0.9

	UPDATE [dbo].[LostSalesAnalysisJobs]
	SET 
		Status = 4,
		FilledJobResults = GETDATE()
	WHERE Id = @JobId

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
	g4.Id as g4_id, 
	g4.Name as g4_name,
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
	JOIN Groups g4
	ON p.GroupId = g4.Id
	JOIN Groups g3
	ON g4.ParentId = g3.Id
	JOIN Groups g2
	ON g3.ParentId = g2.Id
	JOIN Groups g1
	ON g2.ParentId = g1.Id
    JOIN Groups g0
	ON g1.ParentId = g0.Id
	--WHERE p.IsActive = 1

	DECLARE @DtAnalyse Datetime
	SELECT @DtAnalyse = AnalizeDate FROM LostSalesAnalysisJobs WHERE Id = @JobId

	IF @DtAnalyse IS NULL 
	BEGIN
		PRINT 'Не обнаружена или неправильно заполнена строка server_Runs, Id = ' + CAST(@JobId as varchar(128))
		RETURN 
	END

	-- [25.07]
	-- 
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
			ON lsp.DateStart = srp.DateStart
			AND lsp.LocationId = srp.LocationId
			AND lsp.ProductId = srp.ProductId			
		LEFT JOIN 
			(SELECT LostSalesAnalysisTaskId, SUM(Quantity) as sm
			 FROM LostSalesAnalysisResultHourlies
			 WHERE LostSalesAnalysisJobId = @JobId
			 AND CAST(Date as Date) = @DtAnalyse
			 GROUP BY LostSalesAnalysisTaskId
			) as sel
			ON sel.LostSalesAnalysisTaskId = srp.LostSalesAnalysisTaskId
	WHERE srp.LostSalesAnalysisJobId = @JobId

		DECLARE @analyzeDate date = CAST(@DtAnalyse AS date)


	;WITH promo AS
	(
		SELECT
			p.Id PromotionId,
			p.PromotionTypeId,
			DATEDIFF(DAY, p.StartDate, p.EndDate) + 1 PromoLength,
			(DATEDIFF(DAY, p.StartDate, @analyzeDate)) / 7 + 1 WeekNumber
		FROM dbo.Promotions p
		WHERE p.StartDate <= @analyzeDate
		AND p.EndDate >= @analyzeDate
	),
	promoCoeffs AS
	(
		SELECT
			pm.LocationId,
			pm.ProductId,
			CAST(AVG(ptc.Coefficient) AS real) Coeff
		FROM dbo.PromotionTypeCoefficients ptc
		JOIN promo p
		ON ptc.PromotionTypeId = p.PromotionTypeId
		AND ptc.WeekNumber = p.WeekNumber
		AND ptc.PromotionLength = p.PromoLength
		--AND ptc.PromotionLength * 7 >= p.PromoLength
		--AND ptc.PromotionLength * 7 - 6 <= p.PromoLength
		JOIN dbo.PromotionMatrix pm
		ON pm.PromotionId = p.PromotionId
		GROUP BY pm.LocationId,
			pm.ProductId
	)
	-- [LostSalesHourly]

	/*
	-- [25.07]
	-- [no update of past periods]
	UPDATE [LostSalesHours] 
	SET 
		Quantity = srh.Quantity,
		Revenue = st.[Price]*srh.Quantity	
	FROM
		[dbo].[LostSalesHours] lsh
		JOIN [dbo].LostSalesAnalysisResultHourlies srh
			ON lsh.Date = srh.Date
			AND lsh.LocationId = srh.LocationId
			AND lsh.ProductId = srh.ProductId
		JOIN LostSalesAnalysisTasks st
			ON srh.LostSalesAnalysisTaskId = st.Id
	WHERE srh.LostSalesAnalysisJobId = @JobId
		AND srh.Probability > @Probability
		AND srh.Quantity > 0
	*/			

	INSERT INTO [LostSalesHours](LocationId, ProductId, Date, Quantity, Revenue)
	SELECT
		srh.LocationId,
		srh.ProductId,
		srh.Date,
		CASE WHEN ISNULL(srh.IsCalculatedInTsa, 0) = 1
			THEN srh.Quantity * ISNULL(tmp.coeff, 1) * ISNULL(pc.Coeff, 1)
			ELSE srh.Quantity * ISNULL(tmp.coeff, 1) END,
		CASE WHEN ISNULL(srh.IsCalculatedInTsa, 0) = 1
			THEN srh.Quantity * st.Price * ISNULL(tmp.coeff, 1) * ISNULL(pc.Coeff, 1)
			ELSE srh.Quantity * st.Price * ISNULL(tmp.coeff, 1) END
	FROM
		[dbo].LostSalesAnalysisResultHourlies srh
		/*
		-- [25.07]
		-- [no update of past periods]
		LEFT JOIN [dbo].[LostSalesHours] lsh
			ON lsh.Date = srh.Date
			AND lsh.LocationId = srh.LocationId
			AND lsh.ProductId = srh.ProductId	
			AND srh.LostSalesAnalysisJobId = @JobId		
		*/
		JOIN LostSalesAnalysisTasks st
			ON srh.LostSalesAnalysisTaskId = st.Id			
		-- [25.07]
		-- [no update of past periods]
		LEFT JOIN #tmp_table tmp 
			ON tmp.LostSalesAnalysisTaskId = srh.LostSalesAnalysisTaskId
		LEFT JOIN promoCoeffs pc
			ON pc.LocationId = st.LocationId
			AND pc.ProductId = st.ProductId
	WHERE 
		/*
		-- [25.07]
		-- [no update of past periods]
		lsh.LocationID is NULL AND	
		*/
		srh.Probability > @Probability -- todo
		AND srh.LostSalesAnalysisJobId = @JobId
		AND srh.Quantity > 0
		-- [25.07]
		AND CAST(srh.Date as Date) = @DtAnalyse
		
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
		AND srp.Probability > @Probability
		AND srp.Quantity > 0	
	
	INSERT INTO LostSalesPeriods (LocationId, ProductId, DateStart, DateEnd, HoursCount, Quantity, Revenue)
	SELECT srp.LocationId, srp.ProductId, srp.DateStart, srp.DateEnd, srp.HoursCount, srp.Quantity, srp.Quantity*st.Price
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
		AND srp.Probability > @Probability
		AND srp.LostSalesAnalysisJobId = @JobId
		AND srp.Quantity > 0
		
	-- no update - just insert
		
	Declare @dt_renew date
	SELECT @dt_renew = 
		-- CAST(MIN(DateStart) as date) FROM LostSalesAnalysisResultPeriods WHERE LostSalesAnalysisJobId = @JobId AND Probability > @Probability
		-- [25.07]
		-- No update of past periods
		@DtAnalyse
		
	-- LostSalesDaily

	DELETE FROM LostSalesDays
	WHERE LocationId IN (SELECT DISTINCT LocationId FROM LostSalesAnalysisResultPeriods WHERE LostSalesAnalysisJobId = @JobId AND Probability > @Probability)
		AND [Date] >= @dt_renew

	INSERT INTO LostSalesDays([LocationId], [ProductId], [Date], [Quantity], [Revenue], [HourCount])
	SELECT [LocationId], [ProductId], CAST([Date] as Date), SUM([Quantity]), SUM([Revenue]), Count([LocationId])
	FROM [LostSalesHours] 
	WHERE 
		LocationId IN (SELECT DISTINCT LocationId FROM LostSalesAnalysisResultPeriods WHERE LostSalesAnalysisJobId = @JobId AND Probability > @Probability)
		AND [Date] >= @dt_renew
	GROUP BY [LocationId], [ProductId], CAST([Date] as Date)		

	
	ALTER INDEX [IX_LostSalesDays] ON [dbo].LostSalesDays REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
	
	-- [LostSalesDayGroups] 
	
	DELETE FROM [LostSalesDayGroups]
	WHERE [Date] >= @dt_renew
	
	;WITH significantPromo AS
(
	SELECT
		pm.LocationId,
		pm.ProductId,
		c.Date
	FROM [dbo].[PromotionMatrix] pm
	JOIN [dbo].[Promotions] promo
	ON promo.Id = [PM].PromotionId
	JOIN [dbo].CalendarDimensions c
	ON promo.StartDate <= c.Date 
	AND promo.EndDate >= c.Date
    WHERE promo.PromotionTypeId IN (12, 14, 15, 18, 20, 21)	
	GROUP BY pm.LocationId, pm.ProductId, c.Date
)
	
	INSERT INTO [LostSalesDayGroups]
	([GroupId], [LocationId], [Date], [AbcCategory], [Quantity], [Revenue], 
	[KviQuantity], [KviRevenue], [PromoQuantity], [PromoRevenue], [AutoOrderQuantity], [AutoOrderRevenue],
	[SignificantPromoQuantity], [SignificantPromoRevenue], [NonSignificantPromoQuantity], [NonSignificantPromoRevenue],
	[GroupLevel])
    SELECT [PG].[GroupId4] AS [GroupId]
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
			,4 AS [GroupLevel]
    FROM [dbo].LostSalesDays [PS]
        INNER JOIN #ProductGroups [PG] ON [PG].ProductId = [PS].ProductId    
		INNER JOIN [dbo].[AssortmentMatrix] [AM] ON [AM].[LocationId] = [PS].[LocationId] AND [AM].[ProductId] = [PS].[ProductId] AND [AM].[Date] = [PS].[Date]
		LEFT JOIN significantPromo spr
			ON spr.LocationId = [AM].LocationId
			AND spr.ProductId = [AM].ProductId
			AND spr.Date = [AM].Date
    WHERE [PS].[Date] >= @dt_renew
    GROUP BY [PG].[GroupId4], [PS].[LocationId], [PS].[Date], [AM].[AbcCategory]

	-- g3
	INSERT INTO [LostSalesDayGroups]
	([GroupId], [LocationId], [Date], [AbcCategory], [Quantity], [Revenue],
	[KviQuantity], [KviRevenue], [PromoQuantity], [PromoRevenue], [AutoOrderQuantity], [AutoOrderRevenue],
	[SignificantPromoQuantity], [SignificantPromoRevenue], [NonSignificantPromoQuantity], [NonSignificantPromoRevenue],
	[GroupLevel])
    SELECT GroupId3
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
			,3 AS [GroupLevel]
    FROM [dbo].[LostSalesDayGroups] lsds
        JOIN (SELECT DISTINCT GroupId4, GroupId3 FROM #ProductGroups) p ON p.GroupId4 = lsds.GroupId AND GroupLevel = 4 
    WHERE [Date] >= @dt_renew
    GROUP BY GroupId3, lsds.LocationId, Date, AbcCategory
	
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
	
	-- [/LostSalesDayGroups]

	-- [LostSalesHourGroups] 
	
	--DELETE FROM LostSalesHourGroups
	--WHERE [Date] >= @dt_renew
	
	---- g4
	--INSERT INTO LostSalesHourGroups (GroupId, LocationId, Date, Quantity, Revenue)
 --   SELECT GroupId4, Loc.ID, Date, SUM(QUantity) as quantity, SUM(REVENUE) as revenue
 --   FROM [dbo].LostSalesHours ps
 --       JOIN Locations loc ON loc.Id = ps.LocationId
 --       JOIN #ProductGroups p ON p.ProductId = ps.ProductId            
 --      --WHERE Date = '2015-04-09'
 --   WHERE [Date] >= @dt_renew
 --   GROUP BY GroupId4, Loc.ID, Date	

	/*
	-- g3
	INSERT INTO LostSalesHourGroups (GroupId, LocationId, Date, Quantity, Revenue, GroupLevel)
    SELECT GroupId3, lsds.LocationId, Date, SUM(QUantity) as quantity, SUM(REVENUE) as revenue, 3
    FROM [dbo].LostSalesHourGroups lsds
        JOIN (SELECT DISTINCT GroupId4, GroupId3 FROM #ProductGroups) p ON p.GroupId4 = lsds.GroupId
		AND GroupLevel = 4 
       --WHERE Date = '2015-04-09'
    WHERE 
		[Date] >= @dt_renew
    GROUP BY GroupId3, lsds.LocationId, Date
	
	-- g2
	INSERT INTO LostSalesHourGroups (GroupId, LocationId, Date, Quantity, Revenue, GroupLevel)
    SELECT GroupId2, lsds.LocationId, Date, SUM(QUantity) as quantity, SUM(REVENUE) as revenue, 2
    FROM [dbo].LostSalesHourGroups lsds
        JOIN (SELECT DISTINCT GroupId3, GroupId2 FROM #ProductGroups) p ON p.GroupId3 = lsds.GroupId
		AND GroupLevel = 3
       --WHERE Date = '2015-04-09'
    WHERE 
		[Date] >= @dt_renew
    GROUP BY GroupId2, lsds.LocationId, Date
	
	-- g1
	INSERT INTO LostSalesHourGroups (GroupId, LocationId, Date, Quantity, Revenue, GroupLevel)
    SELECT GroupId2, lsds.LocationId, Date, SUM(QUantity) as quantity, SUM(REVENUE) as revenue, 1
    FROM [dbo].LostSalesHourGroups lsds
        JOIN (SELECT DISTINCT GroupId2, GroupId1 FROM #ProductGroups) p ON p.GroupId2 = lsds.GroupId
		AND GroupLevel = 2
       --WHERE Date = '2015-04-09'
    WHERE 
		[Date] >= @dt_renew
    GROUP BY GroupId1, lsds.LocationId, Date		
	
	-- [/LostSalesDayGroups]
	*/

	EXEC [dbo].[LostSalesAnalysisRcaCalculate] @JobId

	EXEC [dbo].[LostSalesAnalysisJobResultsProceedRcaUpdate] @JobId

	UPDATE [dbo].[LostSalesAnalysisJobs]
	SET 
		Status = 5,
		JobResultsProceed = GETDATE()
	WHERE Id = @JobId

END




