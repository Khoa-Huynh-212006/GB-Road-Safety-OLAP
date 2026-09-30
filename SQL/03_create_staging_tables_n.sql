USE RoadSafetyDWH;
GO

/*============================================================
  1. STAGING TABLE: COLLISIONS 
============================================================*/

IF OBJECT_ID(N'stg.Collisions', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Collisions
    (
        collision_index
            VARCHAR(50) NOT NULL,

        longitude
            VARCHAR(30) NULL,

        latitude
            VARCHAR(30) NULL,

        collision_severity
            NVARCHAR(50) NOT NULL,

        [date]
            DATE NOT NULL,

        [time]
            TIME(0) NOT NULL,

        local_authority_ons_district
            VARCHAR(20) NOT NULL,

        first_road_class
            NVARCHAR(100) NOT NULL,

        road_type
            NVARCHAR(150) NOT NULL,

        speed_limit
            VARCHAR(10) NULL,

        junction_detail
            NVARCHAR(200) NOT NULL,

        junction_control
            NVARCHAR(200) NOT NULL,

        pedestrian_crossing
            NVARCHAR(250) NOT NULL,

        light_conditions
            NVARCHAR(200) NOT NULL,

        weather_conditions
            NVARCHAR(200) NOT NULL,

        road_surface_conditions
            NVARCHAR(200) NOT NULL,

        urban_or_rural_area
            NVARCHAR(100) NOT NULL,

        local_authority_ons_district_name
            NVARCHAR(150) NOT NULL
    );

    PRINT N'Đã tạo stg.Collisions.';
END;
GO


/*============================================================
  2. STAGING TABLE: VEHICLES 
============================================================*/

IF OBJECT_ID(N'stg.Vehicles', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Vehicles
    (
        collision_index
            VARCHAR(50) NOT NULL,

        vehicle_reference
            INT NOT NULL,

        vehicle_type
            NVARCHAR(250) NOT NULL,

        vehicle_manoeuvre
            NVARCHAR(250) NOT NULL,

        skidding_and_overturning
            NVARCHAR(250) NOT NULL,

        vehicle_leaving_carriageway
            NVARCHAR(250) NOT NULL,

        sex_of_driver
            NVARCHAR(100) NOT NULL,

        age_band_of_driver
            NVARCHAR(100) NOT NULL
    );

    PRINT N'Đã tạo stg.Vehicles.';
END;
GO


/*============================================================
  3. STAGING TABLE: CASUALTIES 
============================================================*/

IF OBJECT_ID(N'stg.Casualties', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Casualties
    (
        collision_index
            VARCHAR(50) NOT NULL,

        vehicle_reference
            INT NOT NULL,

        casualty_reference
            INT NOT NULL,

        casualty_class
            NVARCHAR(100) NOT NULL,

        sex_of_casualty
            NVARCHAR(100) NOT NULL,

        age_band_of_casualty
            NVARCHAR(100) NOT NULL,

        casualty_severity
            NVARCHAR(50) NOT NULL,

        casualty_type
            NVARCHAR(250) NOT NULL
    );

    PRINT N'Đã tạo stg.Casualties.';
END;
GO

