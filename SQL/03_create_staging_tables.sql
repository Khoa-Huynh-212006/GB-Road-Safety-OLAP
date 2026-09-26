USE STATS19_DW;
GO

IF SCHEMA_ID(N'stg') IS NULL
    EXEC(N'CREATE SCHEMA stg');
GO

IF OBJECT_ID(N'stg.Collisions', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Collisions
    (
        collision_id                   VARCHAR(20)   NOT NULL,
        collision_year                 SMALLINT      NULL,
        collision_date                 DATE          NULL,
        collision_time                 TIME(0)       NULL,
        longitude                      DECIMAL(10,6) NULL,
        latitude                       DECIMAL(10,6) NULL,
        local_authority_district_code  VARCHAR(20)   NULL,
        collision_severity             NVARCHAR(50)  NULL,
        first_road_class               NVARCHAR(100) NULL,
        road_type                      NVARCHAR(100) NULL,
        speed_limit_mph                SMALLINT      NULL,
        junction_detail                NVARCHAR(150) NULL,
        junction_control               NVARCHAR(150) NULL,
        pedestrian_crossing            NVARCHAR(150) NULL,
        light_conditions               NVARCHAR(150) NULL,
        weather_conditions             NVARCHAR(150) NULL,
        road_surface_conditions        NVARCHAR(150) NULL,
        area_type                      NVARCHAR(50)  NULL
    );
END;
GO

IF OBJECT_ID(N'stg.Vehicles', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Vehicles
    (
        collision_id                  VARCHAR(20)   NOT NULL,
        vehicle_reference              INT           NOT NULL,
        vehicle_type                   NVARCHAR(150) NULL,
        vehicle_manoeuvre              NVARCHAR(150) NULL,
        driver_age_band                NVARCHAR(100) NULL,
        driver_sex                     NVARCHAR(50)  NULL,
        skidding_and_overturning       NVARCHAR(150) NULL,
        vehicle_leaving_carriageway    NVARCHAR(150) NULL
    );
END;
GO

IF OBJECT_ID(N'stg.Casualties', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Casualties
    (
        collision_id          VARCHAR(20)   NOT NULL,
        vehicle_reference     INT           NULL,
        casualty_reference   INT           NOT NULL,
        casualty_class        NVARCHAR(100) NULL,
        casualty_sex          NVARCHAR(50)  NULL,
        casualty_age          SMALLINT      NULL,
        casualty_age_band     NVARCHAR(100) NULL,
        casualty_severity     NVARCHAR(50)  NULL,
        casualty_type         NVARCHAR(150) NULL,
        pedestrian_location   NVARCHAR(150) NULL,
        pedestrian_movement   NVARCHAR(150) NULL
    );
END;
GO