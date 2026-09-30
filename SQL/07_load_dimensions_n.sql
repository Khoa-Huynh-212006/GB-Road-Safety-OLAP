-- Lưu ý: script này có TRUNCATE, chỉ nên dùng ở giai đoạn hiện tại khi chưa tạo FactCasualty.
USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;


    /*========================================================
      RESET DIMENSIONS

      Hiện tại chưa có Fact nên có thể TRUNCATE an toàn.
      TRUNCATE cũng reset các IDENTITY về 1.
    ========================================================*/

    TRUNCATE TABLE dwh.DimCasualtySeverity;
    TRUNCATE TABLE dwh.DimCollisionSeverity;
    TRUNCATE TABLE dwh.DimCasualty;
    TRUNCATE TABLE dwh.DimDriver;
    TRUNCATE TABLE dwh.DimVehicle;
    TRUNCATE TABLE dwh.DimEnvironment;
    TRUNCATE TABLE dwh.DimJunction;
    TRUNCATE TABLE dwh.DimRoad;
    TRUNCATE TABLE dwh.DimLocation;
    TRUNCATE TABLE dwh.DimTime;
    TRUNCATE TABLE dwh.DimDate;


    /*========================================================
      1. LOAD DIM DATE
    ========================================================*/

    ;WITH DistinctDates AS
    (
        SELECT DISTINCT
            [date] AS FullDate
        FROM stg.Collisions
    ),
    DateAttributes AS
    (
        SELECT
            FullDate,

            CAST(
                (
                    (
                        DATEDIFF(
                            DAY,
                            CONVERT(DATE, '19000101', 112),
                            FullDate
                        ) % 7
                    ) + 7
                ) % 7 + 1
                AS TINYINT
            ) AS DayOfWeekNumber
        FROM DistinctDates
    )
    INSERT INTO dwh.DimDate
    (
        DateKey,
        FullDate,
        [Day],
        MonthNumber,
        MonthName,
        [Quarter],
        [Year],
        DayOfWeekNumber,
        DayOfWeekName,
        IsWeekend
    )
    SELECT
        CONVERT(
            INT,
            CONVERT(CHAR(8), FullDate, 112)
        ) AS DateKey,

        FullDate,

        DATEPART(DAY, FullDate),

        DATEPART(MONTH, FullDate),

        CHOOSE(
            DATEPART(MONTH, FullDate),
            N'January',
            N'February',
            N'March',
            N'April',
            N'May',
            N'June',
            N'July',
            N'August',
            N'September',
            N'October',
            N'November',
            N'December'
        ),

        DATEPART(QUARTER, FullDate),

        DATEPART(YEAR, FullDate),

        DayOfWeekNumber,

        CHOOSE(
            DayOfWeekNumber,
            N'Monday',
            N'Tuesday',
            N'Wednesday',
            N'Thursday',
            N'Friday',
            N'Saturday',
            N'Sunday'
        ),

        CASE
            WHEN DayOfWeekNumber IN (6, 7)
                THEN 1
            ELSE 0
        END
    FROM DateAttributes;


    /*========================================================
      2. LOAD DIM TIME
    ========================================================*/

    INSERT INTO dwh.DimTime
    (
        TimeKey,
        FullTime,
        [Hour],
        [Minute],
        TimeBand
    )
    SELECT
        DATEPART(HOUR, DistinctTimes.FullTime) * 100
        + DATEPART(MINUTE, DistinctTimes.FullTime),

        DistinctTimes.FullTime,

        DATEPART(HOUR, DistinctTimes.FullTime),

        DATEPART(MINUTE, DistinctTimes.FullTime),

        CASE
            WHEN DATEPART(HOUR, DistinctTimes.FullTime)
                BETWEEN 0 AND 5
                THEN N'Night'

            WHEN DATEPART(HOUR, DistinctTimes.FullTime)
                BETWEEN 6 AND 11
                THEN N'Morning'

            WHEN DATEPART(HOUR, DistinctTimes.FullTime)
                BETWEEN 12 AND 17
                THEN N'Afternoon'

            ELSE N'Evening'
        END
    FROM
    (
        SELECT DISTINCT
            [time] AS FullTime
        FROM stg.Collisions
    ) AS DistinctTimes;


    /*========================================================
      3. LOAD DIM LOCATION
    ========================================================*/

    INSERT INTO dwh.DimLocation
    (
        LocalAuthorityCode,
        LocalAuthorityName
    )
    SELECT DISTINCT
        LTRIM(RTRIM(
            local_authority_ons_district
        )),

        LTRIM(RTRIM(
            local_authority_ons_district_name
        ))
    FROM stg.Collisions;


    /*========================================================
      4. LOAD DIM ROAD
    ========================================================*/

    INSERT INTO dwh.DimRoad
    (
        FirstRoadClass,
        RoadType,
        SpeedLimit,
        UrbanOrRuralArea
    )
    SELECT DISTINCT
        LTRIM(RTRIM(first_road_class)),

        LTRIM(RTRIM(road_type)),

        TRY_CONVERT(
            SMALLINT,
            NULLIF(
                LTRIM(RTRIM(speed_limit)),
                ''
            )
        ),

        LTRIM(RTRIM(urban_or_rural_area))
    FROM stg.Collisions;


    /*========================================================
      5. LOAD DIM JUNCTION
    ========================================================*/

    INSERT INTO dwh.DimJunction
    (
        JunctionDetail,
        JunctionControl,
        PedestrianCrossing
    )
    SELECT DISTINCT
        LTRIM(RTRIM(junction_detail)),
        LTRIM(RTRIM(junction_control)),
        LTRIM(RTRIM(pedestrian_crossing))
    FROM stg.Collisions;


    /*========================================================
      6. LOAD DIM ENVIRONMENT
    ========================================================*/

    INSERT INTO dwh.DimEnvironment
    (
        LightConditions,
        WeatherConditions,
        RoadSurfaceConditions
    )
    SELECT DISTINCT
        LTRIM(RTRIM(light_conditions)),
        LTRIM(RTRIM(weather_conditions)),
        LTRIM(RTRIM(road_surface_conditions))
    FROM stg.Collisions;


    /*========================================================
      7. LOAD DIM VEHICLE
    ========================================================*/

    INSERT INTO dwh.DimVehicle
    (
        VehicleType,
        VehicleManoeuvre,
        SkiddingAndOverturning,
        VehicleLeavingCarriageway
    )
    SELECT DISTINCT
        LTRIM(RTRIM(vehicle_type)),
        LTRIM(RTRIM(vehicle_manoeuvre)),
        LTRIM(RTRIM(skidding_and_overturning)),
        LTRIM(RTRIM(vehicle_leaving_carriageway))
    FROM stg.Vehicles;


    /*========================================================
      8. LOAD DIM DRIVER
    ========================================================*/

    INSERT INTO dwh.DimDriver
    (
        SexOfDriver,
        AgeBandOfDriver
    )
    SELECT DISTINCT
        LTRIM(RTRIM(sex_of_driver)),
        LTRIM(RTRIM(age_band_of_driver))
    FROM stg.Vehicles;


    /*========================================================
      9. LOAD DIM CASUALTY
    ========================================================*/

    INSERT INTO dwh.DimCasualty
    (
        CasualtyClass,
        SexOfCasualty,
        AgeBandOfCasualty,
        CasualtyType
    )
    SELECT DISTINCT
        LTRIM(RTRIM(casualty_class)),
        LTRIM(RTRIM(sex_of_casualty)),
        LTRIM(RTRIM(age_band_of_casualty)),
        LTRIM(RTRIM(casualty_type))
    FROM stg.Casualties;


    /*========================================================
      10. LOAD DIM COLLISION SEVERITY
    ========================================================*/

    INSERT INTO dwh.DimCollisionSeverity
    (
        CollisionSeverity,
        CollisionSeverityGroup
    )
    SELECT DISTINCT
        LTRIM(RTRIM(collision_severity)),

        CASE
            WHEN LTRIM(RTRIM(collision_severity))
                IN (N'Fatal', N'Serious')
                THEN N'KSI'

            ELSE N'Non-KSI'
        END
    FROM stg.Collisions;


    /*========================================================
      11. LOAD DIM CASUALTY SEVERITY
    ========================================================*/

    INSERT INTO dwh.DimCasualtySeverity
    (
        CasualtySeverity,
        CasualtySeverityGroup
    )
    SELECT DISTINCT
        LTRIM(RTRIM(casualty_severity)),

        CASE
            WHEN LTRIM(RTRIM(casualty_severity))
                IN (N'Fatal', N'Serious')
                THEN N'KSI'

            ELSE N'Non-KSI'
        END
    FROM stg.Casualties;


    /*========================================================
      BASIC VALIDATION BEFORE COMMIT
    ========================================================*/

    IF (SELECT COUNT_BIG(*) FROM dwh.DimDate) <> 1826
        THROW 50101, N'DimDate không có đúng 1826 dòng.', 1;

    IF (SELECT COUNT_BIG(*) FROM dwh.DimTime) <> 1440
        THROW 50102, N'DimTime không có đúng 1440 dòng.', 1;

    IF (SELECT COUNT_BIG(*) FROM dwh.DimLocation) <> 370
        THROW 50103, N'DimLocation không có đúng 370 dòng.', 1;

    IF (
        SELECT COUNT_BIG(*)
        FROM dwh.DimCollisionSeverity
    ) <> 3
        THROW 50104,
            N'DimCollisionSeverity không có đúng 3 dòng.',
            1;

    IF (
        SELECT COUNT_BIG(*)
        FROM dwh.DimCasualtySeverity
    ) <> 3
        THROW 50105,
            N'DimCasualtySeverity không có đúng 3 dòng.',
            1;


    COMMIT TRANSACTION;

    PRINT N'Đã nạp thành công toàn bộ 11 Dimension.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT N'Load Dimension thất bại. Transaction đã rollback.';

    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage;

    THROW;
END CATCH;
GO