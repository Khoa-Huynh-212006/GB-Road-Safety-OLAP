USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
GO

/*============================================================
  PHẦN A — PROFILING DIMENSION TABLES
============================================================*/


/*------------------------------------------------------------
  A1. Số dòng của từng Dimension
------------------------------------------------------------*/

SELECT 'DimDate' AS DimensionName, COUNT_BIG(*) AS RC
FROM dwh.DimDate

UNION ALL

SELECT 'DimTime', COUNT_BIG(*)
FROM dwh.DimTime

UNION ALL

SELECT 'DimLocation', COUNT_BIG(*)
FROM dwh.DimLocation

UNION ALL

SELECT 'DimRoad', COUNT_BIG(*)
FROM dwh.DimRoad

UNION ALL

SELECT 'DimJunction', COUNT_BIG(*)
FROM dwh.DimJunction

UNION ALL

SELECT 'DimEnvironment', COUNT_BIG(*)
FROM dwh.DimEnvironment

UNION ALL

SELECT 'DimVehicle', COUNT_BIG(*)
FROM dwh.DimVehicle

UNION ALL

SELECT 'DimDriver', COUNT_BIG(*)
FROM dwh.DimDriver

UNION ALL

SELECT 'DimCasualty', COUNT_BIG(*)
FROM dwh.DimCasualty

UNION ALL

SELECT 'DimCollisionSeverity', COUNT_BIG(*)
FROM dwh.DimCollisionSeverity

UNION ALL

SELECT 'DimCasualtySeverity', COUNT_BIG(*)
FROM dwh.DimCasualtySeverity

ORDER BY DimensionName;
GO


/*------------------------------------------------------------
  A2. Kiểm tra surrogate key

  Mỗi Dimension phải thỏa:
  - Số dòng = số key phân biệt
  - Không có key NULL
------------------------------------------------------------*/

SELECT
    'DimDate' AS DimensionName,
    COUNT_BIG(*) AS TotalRows,
    COUNT_BIG(DISTINCT DateKey) AS DistinctKeys,
    SUM(CASE WHEN DateKey IS NULL THEN 1 ELSE 0 END) AS NullKeys,
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT DateKey)
         AND SUM(CASE WHEN DateKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS Status
FROM dwh.DimDate

UNION ALL

SELECT
    'DimTime',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT TimeKey),
    SUM(CASE WHEN TimeKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT TimeKey)
         AND SUM(CASE WHEN TimeKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimTime

UNION ALL

SELECT
    'DimLocation',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT LocationKey),
    SUM(CASE WHEN LocationKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT LocationKey)
         AND SUM(CASE WHEN LocationKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimLocation

UNION ALL

SELECT
    'DimRoad',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT RoadKey),
    SUM(CASE WHEN RoadKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT RoadKey)
         AND SUM(CASE WHEN RoadKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimRoad

UNION ALL

SELECT
    'DimJunction',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT JunctionKey),
    SUM(CASE WHEN JunctionKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT JunctionKey)
         AND SUM(CASE WHEN JunctionKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimJunction

UNION ALL

SELECT
    'DimEnvironment',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT EnvironmentKey),
    SUM(CASE WHEN EnvironmentKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT EnvironmentKey)
         AND SUM(CASE WHEN EnvironmentKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimEnvironment

UNION ALL

SELECT
    'DimVehicle',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT VehicleKey),
    SUM(CASE WHEN VehicleKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT VehicleKey)
         AND SUM(CASE WHEN VehicleKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimVehicle

UNION ALL

SELECT
    'DimDriver',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT DriverKey),
    SUM(CASE WHEN DriverKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT DriverKey)
         AND SUM(CASE WHEN DriverKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimDriver

UNION ALL

SELECT
    'DimCasualty',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT CasualtyKey),
    SUM(CASE WHEN CasualtyKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT CasualtyKey)
         AND SUM(CASE WHEN CasualtyKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimCasualty

UNION ALL

SELECT
    'DimCollisionSeverity',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT CollisionSeverityKey),
    SUM(CASE WHEN CollisionSeverityKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT CollisionSeverityKey)
         AND SUM(CASE WHEN CollisionSeverityKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimCollisionSeverity

UNION ALL

SELECT
    'DimCasualtySeverity',
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT CasualtySeverityKey),
    SUM(CASE WHEN CasualtySeverityKey IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN COUNT_BIG(*) = COUNT_BIG(DISTINCT CasualtySeverityKey)
         AND SUM(CASE WHEN CasualtySeverityKey IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dwh.DimCasualtySeverity

ORDER BY DimensionName;
GO


/*------------------------------------------------------------
  A3. Kiểm tra trùng grain của từng Dimension

  Kết quả mong đợi:
  Mọi DuplicateGroups đều bằng 0.
------------------------------------------------------------*/

SELECT
    'DimDate' AS DimensionName,
    COUNT_BIG(*) AS DuplicateGroups
FROM
(
    SELECT FullDate
    FROM dwh.DimDate
    GROUP BY FullDate
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimTime',
    COUNT_BIG(*)
FROM
(
    SELECT FullTime
    FROM dwh.DimTime
    GROUP BY FullTime
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimLocation',
    COUNT_BIG(*)
FROM
(
    SELECT LocalAuthorityCode
    FROM dwh.DimLocation
    GROUP BY LocalAuthorityCode
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimRoad',
    COUNT_BIG(*)
FROM
(
    SELECT
        FirstRoadClass,
        RoadType,
        SpeedLimit,
        UrbanOrRuralArea
    FROM dwh.DimRoad
    GROUP BY
        FirstRoadClass,
        RoadType,
        SpeedLimit,
        UrbanOrRuralArea
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimJunction',
    COUNT_BIG(*)
FROM
(
    SELECT
        JunctionDetail,
        JunctionControl,
        PedestrianCrossing
    FROM dwh.DimJunction
    GROUP BY
        JunctionDetail,
        JunctionControl,
        PedestrianCrossing
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimEnvironment',
    COUNT_BIG(*)
FROM
(
    SELECT
        LightConditions,
        WeatherConditions,
        RoadSurfaceConditions
    FROM dwh.DimEnvironment
    GROUP BY
        LightConditions,
        WeatherConditions,
        RoadSurfaceConditions
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimVehicle',
    COUNT_BIG(*)
FROM
(
    SELECT
        VehicleType,
        VehicleManoeuvre,
        SkiddingAndOverturning,
        VehicleLeavingCarriageway
    FROM dwh.DimVehicle
    GROUP BY
        VehicleType,
        VehicleManoeuvre,
        SkiddingAndOverturning,
        VehicleLeavingCarriageway
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimDriver',
    COUNT_BIG(*)
FROM
(
    SELECT
        SexOfDriver,
        AgeBandOfDriver
    FROM dwh.DimDriver
    GROUP BY
        SexOfDriver,
        AgeBandOfDriver
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimCasualty',
    COUNT_BIG(*)
FROM
(
    SELECT
        CasualtyClass,
        SexOfCasualty,
        AgeBandOfCasualty,
        CasualtyType
    FROM dwh.DimCasualty
    GROUP BY
        CasualtyClass,
        SexOfCasualty,
        AgeBandOfCasualty,
        CasualtyType
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimCollisionSeverity',
    COUNT_BIG(*)
FROM
(
    SELECT CollisionSeverity
    FROM dwh.DimCollisionSeverity
    GROUP BY CollisionSeverity
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

UNION ALL

SELECT
    'DimCasualtySeverity',
    COUNT_BIG(*)
FROM
(
    SELECT CasualtySeverity
    FROM dwh.DimCasualtySeverity
    GROUP BY CasualtySeverity
    HAVING COUNT_BIG(*) > 1
) AS Duplicates

ORDER BY DimensionName;
GO