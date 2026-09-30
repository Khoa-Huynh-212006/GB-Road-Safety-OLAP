USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;


    /*========================================================
      RESET FACT

      Hiện tại chưa có Foreign Key từ bảng khác tới Fact,
      nên có thể TRUNCATE an toàn.
    ========================================================*/

    TRUNCATE TABLE dwh.FactCasualty;


    /*========================================================
      PREPARE SOURCE DATA

      - Trim categorical labels.
      - Convert coordinate strings to decimal.
      - Convert blank speed_limit to NULL.
    ========================================================*/

    ;WITH PreparedCollisions AS
    (
        SELECT
            LTRIM(RTRIM(collision_index))
                AS CollisionIndex,

            [date]
                AS FullDate,

            [time]
                AS FullTime,

            TRY_CONVERT(
                DECIMAL(9,6),
                TRY_CONVERT(
                    FLOAT,
                    NULLIF(
                        LTRIM(RTRIM(longitude)),
                        ''
                    )
                )
            ) AS Longitude,

            TRY_CONVERT(
                DECIMAL(9,6),
                TRY_CONVERT(
                    FLOAT,
                    NULLIF(
                        LTRIM(RTRIM(latitude)),
                        ''
                    )
                )
            ) AS Latitude,

            LTRIM(RTRIM(
                local_authority_ons_district
            )) AS LocalAuthorityCode,

            LTRIM(RTRIM(
                collision_severity
            )) AS CollisionSeverity,

            LTRIM(RTRIM(
                first_road_class
            )) AS FirstRoadClass,

            LTRIM(RTRIM(
                road_type
            )) AS RoadType,

            TRY_CONVERT(
                SMALLINT,
                NULLIF(
                    LTRIM(RTRIM(speed_limit)),
                    ''
                )
            ) AS SpeedLimit,

            LTRIM(RTRIM(
                junction_detail
            )) AS JunctionDetail,

            LTRIM(RTRIM(
                junction_control
            )) AS JunctionControl,

            LTRIM(RTRIM(
                pedestrian_crossing
            )) AS PedestrianCrossing,

            LTRIM(RTRIM(
                light_conditions
            )) AS LightConditions,

            LTRIM(RTRIM(
                weather_conditions
            )) AS WeatherConditions,

            LTRIM(RTRIM(
                road_surface_conditions
            )) AS RoadSurfaceConditions,

            LTRIM(RTRIM(
                urban_or_rural_area
            )) AS UrbanOrRuralArea
        FROM stg.Collisions
    ),

    PreparedVehicles AS
    (
        SELECT
            LTRIM(RTRIM(collision_index))
                AS CollisionIndex,

            vehicle_reference
                AS VehicleReference,

            LTRIM(RTRIM(vehicle_type))
                AS VehicleType,

            LTRIM(RTRIM(vehicle_manoeuvre))
                AS VehicleManoeuvre,

            LTRIM(RTRIM(
                skidding_and_overturning
            )) AS SkiddingAndOverturning,

            LTRIM(RTRIM(
                vehicle_leaving_carriageway
            )) AS VehicleLeavingCarriageway,

            LTRIM(RTRIM(sex_of_driver))
                AS SexOfDriver,

            LTRIM(RTRIM(age_band_of_driver))
                AS AgeBandOfDriver
        FROM stg.Vehicles
    ),

    PreparedCasualties AS
    (
        SELECT
            LTRIM(RTRIM(collision_index))
                AS CollisionIndex,

            vehicle_reference
                AS VehicleReference,

            casualty_reference
                AS CasualtyReference,

            LTRIM(RTRIM(casualty_class))
                AS CasualtyClass,

            LTRIM(RTRIM(sex_of_casualty))
                AS SexOfCasualty,

            LTRIM(RTRIM(age_band_of_casualty))
                AS AgeBandOfCasualty,

            LTRIM(RTRIM(casualty_severity))
                AS CasualtySeverity,

            LTRIM(RTRIM(casualty_type))
                AS CasualtyType
        FROM stg.Casualties
    )

    INSERT INTO dwh.FactCasualty WITH (TABLOCK)
    (
        DateKey,
        TimeKey,
        LocationKey,
        RoadKey,
        JunctionKey,
        EnvironmentKey,
        CollisionSeverityKey,
        VehicleKey,
        DriverKey,
        CasualtyKey,
        CasualtySeverityKey,

        CollisionIndex,
        VehicleReference,
        CasualtyReference,
        VehicleInvolvementID,

        Longitude,
        Latitude,

        CasualtyCount,
        KSICasualtyCount
    )
    SELECT
        dd.DateKey,
        dt.TimeKey,
        dl.LocationKey,
        dr.RoadKey,
        dj.JunctionKey,
        de.EnvironmentKey,
        dcs.CollisionSeverityKey,
        dv.VehicleKey,
        ddr.DriverKey,
        dc.CasualtyKey,
        dcas.CasualtySeverityKey,

        ca.CollisionIndex,
        ca.VehicleReference,
        ca.CasualtyReference,

        CONCAT(
            ca.CollisionIndex,
            '-',
            ca.VehicleReference
        ) AS VehicleInvolvementID,

        c.Longitude,
        c.Latitude,

        1 AS CasualtyCount,

        CASE
            WHEN dcas.CasualtySeverityGroup = N'KSI'
                THEN 1
            ELSE 0
        END AS KSICasualtyCount

    FROM PreparedCasualties AS ca

    INNER JOIN PreparedCollisions AS c
        ON ca.CollisionIndex = c.CollisionIndex

    INNER JOIN PreparedVehicles AS v
        ON ca.CollisionIndex = v.CollisionIndex
        AND ca.VehicleReference = v.VehicleReference

    INNER JOIN dwh.DimDate AS dd
        ON c.FullDate = dd.FullDate

    INNER JOIN dwh.DimTime AS dt
        ON c.FullTime = dt.FullTime

    INNER JOIN dwh.DimLocation AS dl
        ON c.LocalAuthorityCode =
           dl.LocalAuthorityCode

    INNER JOIN dwh.DimRoad AS dr
        ON c.FirstRoadClass = dr.FirstRoadClass
        AND c.RoadType = dr.RoadType
        AND c.UrbanOrRuralArea =
            dr.UrbanOrRuralArea
        AND
        (
            c.SpeedLimit = dr.SpeedLimit
            OR
            (
                c.SpeedLimit IS NULL
                AND dr.SpeedLimit IS NULL
            )
        )

    INNER JOIN dwh.DimJunction AS dj
        ON c.JunctionDetail = dj.JunctionDetail
        AND c.JunctionControl = dj.JunctionControl
        AND c.PedestrianCrossing =
            dj.PedestrianCrossing

    INNER JOIN dwh.DimEnvironment AS de
        ON c.LightConditions = de.LightConditions
        AND c.WeatherConditions =
            de.WeatherConditions
        AND c.RoadSurfaceConditions =
            de.RoadSurfaceConditions

    INNER JOIN dwh.DimCollisionSeverity AS dcs
        ON c.CollisionSeverity =
           dcs.CollisionSeverity

    INNER JOIN dwh.DimVehicle AS dv
        ON v.VehicleType = dv.VehicleType
        AND v.VehicleManoeuvre =
            dv.VehicleManoeuvre
        AND v.SkiddingAndOverturning =
            dv.SkiddingAndOverturning
        AND v.VehicleLeavingCarriageway =
            dv.VehicleLeavingCarriageway

    INNER JOIN dwh.DimDriver AS ddr
        ON v.SexOfDriver = ddr.SexOfDriver
        AND v.AgeBandOfDriver =
            ddr.AgeBandOfDriver

    INNER JOIN dwh.DimCasualty AS dc
        ON ca.CasualtyClass = dc.CasualtyClass
        AND ca.SexOfCasualty =
            dc.SexOfCasualty
        AND ca.AgeBandOfCasualty =
            dc.AgeBandOfCasualty
        AND ca.CasualtyType =
            dc.CasualtyType

    INNER JOIN dwh.DimCasualtySeverity AS dcas
        ON ca.CasualtySeverity =
           dcas.CasualtySeverity;


    /*========================================================
      VALIDATE FACT BEFORE COMMIT
    ========================================================*/

    DECLARE @FactRows BIGINT;
    DECLARE @TotalCasualties BIGINT;
    DECLARE @DistinctCollisions BIGINT;
    DECLARE @DistinctVehicles BIGINT;
    DECLARE @DuplicateNaturalKeys BIGINT;
    DECLARE @SourceKSICount BIGINT;
    DECLARE @FactKSICount BIGINT;
    DECLARE @MissingCoordinateCollisions BIGINT;


    SELECT
        @FactRows = COUNT_BIG(*),

        @TotalCasualties =
            SUM(CONVERT(BIGINT, CasualtyCount)),

        @DistinctCollisions =
            COUNT_BIG(DISTINCT CollisionIndex),

        @DistinctVehicles =
            COUNT_BIG(DISTINCT VehicleInvolvementID),

        @FactKSICount =
            SUM(CONVERT(BIGINT, KSICasualtyCount))
    FROM dwh.FactCasualty;


    SELECT
        @DuplicateNaturalKeys = COUNT_BIG(*)
    FROM
    (
        SELECT
            CollisionIndex,
            CasualtyReference
        FROM dwh.FactCasualty
        GROUP BY
            CollisionIndex,
            CasualtyReference
        HAVING COUNT(*) > 1
    ) AS DuplicateFactKeys;


    SELECT
        @SourceKSICount = COUNT_BIG(*)
    FROM stg.Casualties
    WHERE
        LTRIM(RTRIM(casualty_severity))
        IN (N'Fatal', N'Serious');


    SELECT
        @MissingCoordinateCollisions =
            COUNT_BIG(DISTINCT CollisionIndex)
    FROM dwh.FactCasualty
    WHERE
        Longitude IS NULL
        AND Latitude IS NULL;


    IF @FactRows <> 652821
        THROW 50201,
            N'FactCasualty không có đúng 652821 dòng.',
            1;

    IF @TotalCasualties <> 652821
        THROW 50202,
            N'Tổng CasualtyCount không bằng 652821.',
            1;

    IF @DistinctCollisions <> 513801
        THROW 50203,
            N'Fact không chứa đủ 513801 collisions.',
            1;

    IF @DistinctVehicles <> 566945
        THROW 50204,
            N'Số vehicle được Fact tham chiếu không đúng.',
            1;

    IF @DuplicateNaturalKeys <> 0
        THROW 50205,
            N'Natural key của Fact bị trùng.',
            1;

    IF @FactKSICount <> @SourceKSICount
        THROW 50206,
            N'KSI count trong Fact không khớp nguồn.',
            1;

    IF @MissingCoordinateCollisions <> 53
        THROW 50207,
            N'Số collision thiếu tọa độ trong Fact không đúng.',
            1;


    COMMIT TRANSACTION;

    PRINT N'Đã nạp và kiểm tra FactCasualty thành công.';


    /*========================================================
      DISPLAY FACT SUMMARY
    ========================================================*/

    SELECT
        @FactRows AS FactRows,
        @TotalCasualties AS TotalCasualties,
        @DistinctCollisions AS DistinctCollisions,
        @DistinctVehicles AS DistinctVehicles,
        @FactKSICount AS KSICasualties,
        @MissingCoordinateCollisions
            AS MissingCoordinateCollisions;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT N'Load FactCasualty thất bại. Transaction đã rollback.';

    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage;

    THROW;
END CATCH;
GO