USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
GO

DROP TABLE IF EXISTS #QAResults;

CREATE TABLE #QAResults
(
    CheckName     NVARCHAR(200) NOT NULL,
    ExpectedValue BIGINT NOT NULL,
    ActualValue   BIGINT NOT NULL
);


/*============================================================
  1. ROW COUNTS
============================================================*/

INSERT INTO #QAResults
VALUES
(
    N'Collisions row count',
    513801,
    (SELECT COUNT_BIG(*) FROM stg.Collisions)
);

INSERT INTO #QAResults
VALUES
(
    N'Vehicles row count',
    937265,
    (SELECT COUNT_BIG(*) FROM stg.Vehicles)
);

INSERT INTO #QAResults
VALUES
(
    N'Casualties row count',
    652821,
    (SELECT COUNT_BIG(*) FROM stg.Casualties)
);


/*============================================================
  2. MISSING NATURAL KEYS
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Collisions missing collision_index',
    0,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE NULLIF(LTRIM(RTRIM(collision_index)), '') IS NULL;


INSERT INTO #QAResults
SELECT
    N'Vehicles missing natural key',
    0,
    COUNT_BIG(*)
FROM stg.Vehicles
WHERE
    NULLIF(LTRIM(RTRIM(collision_index)), '') IS NULL
    OR vehicle_reference IS NULL;


INSERT INTO #QAResults
SELECT
    N'Casualties missing natural key',
    0,
    COUNT_BIG(*)
FROM stg.Casualties
WHERE
    NULLIF(LTRIM(RTRIM(collision_index)), '') IS NULL
    OR casualty_reference IS NULL;


/*============================================================
  3. DUPLICATE NATURAL KEYS
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Collisions duplicate natural key',
    0,
    COUNT_BIG(*)
FROM
(
    SELECT collision_index
    FROM stg.Collisions
    GROUP BY collision_index
    HAVING COUNT(*) > 1
) AS DuplicateCollisions;


INSERT INTO #QAResults
SELECT
    N'Vehicles duplicate natural key',
    0,
    COUNT_BIG(*)
FROM
(
    SELECT
        collision_index,
        vehicle_reference
    FROM stg.Vehicles
    GROUP BY
        collision_index,
        vehicle_reference
    HAVING COUNT(*) > 1
) AS DuplicateVehicles;


INSERT INTO #QAResults
SELECT
    N'Casualties duplicate natural key',
    0,
    COUNT_BIG(*)
FROM
(
    SELECT
        collision_index,
        casualty_reference
    FROM stg.Casualties
    GROUP BY
        collision_index,
        casualty_reference
    HAVING COUNT(*) > 1
) AS DuplicateCasualties;


/*============================================================
  4. ORPHAN RELATIONSHIPS
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Vehicles without matching Collision',
    0,
    COUNT_BIG(*)
FROM stg.Vehicles AS v
WHERE NOT EXISTS
(
    SELECT 1
    FROM stg.Collisions AS c
    WHERE c.collision_index = v.collision_index
);


INSERT INTO #QAResults
SELECT
    N'Casualties without matching Collision',
    0,
    COUNT_BIG(*)
FROM stg.Casualties AS ca
WHERE NOT EXISTS
(
    SELECT 1
    FROM stg.Collisions AS c
    WHERE c.collision_index = ca.collision_index
);


INSERT INTO #QAResults
SELECT
    N'Casualties without matching Vehicle',
    0,
    COUNT_BIG(*)
FROM stg.Casualties AS ca
WHERE NOT EXISTS
(
    SELECT 1
    FROM stg.Vehicles AS v
    WHERE
        v.collision_index = ca.collision_index
        AND v.vehicle_reference = ca.vehicle_reference
);


/*============================================================
  5. PARENT RECORD COVERAGE
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Collisions without any Vehicle',
    0,
    COUNT_BIG(*)
FROM stg.Collisions AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM stg.Vehicles AS v
    WHERE v.collision_index = c.collision_index
);


INSERT INTO #QAResults
SELECT
    N'Collisions without any Casualty',
    0,
    COUNT_BIG(*)
FROM stg.Collisions AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM stg.Casualties AS ca
    WHERE ca.collision_index = c.collision_index
);


/*============================================================
  6. COORDINATE AND SPEED-LIMIT QUALITY
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Missing longitude',
    53,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE NULLIF(LTRIM(RTRIM(longitude)), '') IS NULL;


INSERT INTO #QAResults
SELECT
    N'Missing latitude',
    53,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE NULLIF(LTRIM(RTRIM(latitude)), '') IS NULL;


INSERT INTO #QAResults
SELECT
    N'Coordinate pair mismatch',
    0,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE
    CASE
        WHEN NULLIF(LTRIM(RTRIM(longitude)), '') IS NULL
        THEN 1 ELSE 0
    END
    <>
    CASE
        WHEN NULLIF(LTRIM(RTRIM(latitude)), '') IS NULL
        THEN 1 ELSE 0
    END;


INSERT INTO #QAResults
SELECT
    N'Invalid nonblank longitude',
    0,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE
    NULLIF(LTRIM(RTRIM(longitude)), '') IS NOT NULL
    AND TRY_CONVERT(FLOAT, longitude) IS NULL;


INSERT INTO #QAResults
SELECT
    N'Invalid nonblank latitude',
    0,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE
    NULLIF(LTRIM(RTRIM(latitude)), '') IS NOT NULL
    AND TRY_CONVERT(FLOAT, latitude) IS NULL;


INSERT INTO #QAResults
SELECT
    N'Missing speed limit',
    3,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE NULLIF(LTRIM(RTRIM(speed_limit)), '') IS NULL;


INSERT INTO #QAResults
SELECT
    N'Invalid or unexpected speed limit',
    0,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE
    NULLIF(LTRIM(RTRIM(speed_limit)), '') IS NOT NULL
    AND
    (
        TRY_CONVERT(SMALLINT, speed_limit) IS NULL
        OR TRY_CONVERT(SMALLINT, speed_limit)
            NOT IN (20, 30, 40, 50, 60, 70)
    );


/*============================================================
  7. DATE AND TIME COVERAGE
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Dates outside 2021-2025',
    0,
    COUNT_BIG(*)
FROM stg.Collisions
WHERE
    [date] < '20210101'
    OR [date] >= '20260101';


INSERT INTO #QAResults
SELECT
    N'Distinct dates',
    1826,
    COUNT_BIG(*)
FROM
(
    SELECT [date]
    FROM stg.Collisions
    GROUP BY [date]
) AS DistinctDates;


INSERT INTO #QAResults
SELECT
    N'Distinct times',
    1440,
    COUNT_BIG(*)
FROM
(
    SELECT [time]
    FROM stg.Collisions
    GROUP BY [time]
) AS DistinctTimes;


/*============================================================
  8. VEHICLE-CASUALTY COVERAGE
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Distinct vehicles referenced by Casualties',
    566945,
    COUNT_BIG(*)
FROM
(
    SELECT
        collision_index,
        vehicle_reference
    FROM stg.Casualties
    GROUP BY
        collision_index,
        vehicle_reference
) AS ReferencedVehicles;


INSERT INTO #QAResults
SELECT
    N'Vehicles without Casualties',
    370320,
    COUNT_BIG(*)
FROM stg.Vehicles AS v
WHERE NOT EXISTS
(
    SELECT 1
    FROM stg.Casualties AS ca
    WHERE
        ca.collision_index = v.collision_index
        AND ca.vehicle_reference = v.vehicle_reference
);


/*============================================================
  9. BLANK CATEGORICAL LABELS
============================================================*/

INSERT INTO #QAResults
SELECT
    N'Blank Collisions categorical labels',
    0,
    COUNT_BIG(*)
FROM stg.Collisions AS c
CROSS APPLY
(
    VALUES
        (c.local_authority_ons_district),
        (c.collision_severity),
        (c.first_road_class),
        (c.road_type),
        (c.junction_detail),
        (c.junction_control),
        (c.pedestrian_crossing),
        (c.light_conditions),
        (c.weather_conditions),
        (c.road_surface_conditions),
        (c.urban_or_rural_area),
        (c.local_authority_ons_district_name)
) AS Labels(LabelValue)
WHERE
    NULLIF(LTRIM(RTRIM(Labels.LabelValue)), '') IS NULL;


INSERT INTO #QAResults
SELECT
    N'Blank Vehicles categorical labels',
    0,
    COUNT_BIG(*)
FROM stg.Vehicles AS v
CROSS APPLY
(
    VALUES
        (v.vehicle_type),
        (v.vehicle_manoeuvre),
        (v.skidding_and_overturning),
        (v.vehicle_leaving_carriageway),
        (v.sex_of_driver),
        (v.age_band_of_driver)
) AS Labels(LabelValue)
WHERE
    NULLIF(LTRIM(RTRIM(Labels.LabelValue)), '') IS NULL;


INSERT INTO #QAResults
SELECT
    N'Blank Casualties categorical labels',
    0,
    COUNT_BIG(*)
FROM stg.Casualties AS ca
CROSS APPLY
(
    VALUES
        (ca.casualty_class),
        (ca.sex_of_casualty),
        (ca.age_band_of_casualty),
        (ca.casualty_severity),
        (ca.casualty_type)
) AS Labels(LabelValue)
WHERE
    NULLIF(LTRIM(RTRIM(Labels.LabelValue)), '') IS NULL;


/*============================================================
  10. DISPLAY FINAL QA RESULT
============================================================*/

SELECT
    CheckName,
    ExpectedValue,
    ActualValue,
    CASE
        WHEN ExpectedValue = ActualValue
        THEN N'PASS'
        ELSE N'FAIL'
    END AS Status
FROM #QAResults
ORDER BY
    CASE
        WHEN ExpectedValue = ActualValue THEN 1
        ELSE 0
    END,
    CheckName;


/*============================================================
  11. STOP IF ANY CHECK FAILED
============================================================*/

IF EXISTS
(
    SELECT 1
    FROM #QAResults
    WHERE ExpectedValue <> ActualValue
)
BEGIN
    THROW 50020,
        N'Staging QA thất bại. Kiểm tra các dòng có Status = FAIL.',
        1;
END;

PRINT N'STAGING QA PASSED: tất cả kiểm tra đều đúng.';
GO