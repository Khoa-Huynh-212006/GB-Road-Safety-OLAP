USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
GO


/*============================================================
  1. DIM DATE
  Grain: one row per date
============================================================*/

IF OBJECT_ID(N'dwh.DimDate', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimDate
    (
        DateKey
            INT NOT NULL,

        FullDate
            DATE NOT NULL,

        [Day]
            TINYINT NOT NULL,

        MonthNumber
            TINYINT NOT NULL,

        MonthName
            NVARCHAR(20) NOT NULL,

        [Quarter]
            TINYINT NOT NULL,

        [Year]
            SMALLINT NOT NULL,

        DayOfWeekNumber
            TINYINT NOT NULL,

        DayOfWeekName
            NVARCHAR(20) NOT NULL,

        IsWeekend
            BIT NOT NULL,

        CONSTRAINT PK_DimDate
            PRIMARY KEY (DateKey),

        CONSTRAINT UQ_DimDate_FullDate
            UNIQUE (FullDate),

        CONSTRAINT CK_DimDate_Month
            CHECK (MonthNumber BETWEEN 1 AND 12),

        CONSTRAINT CK_DimDate_Quarter
            CHECK ([Quarter] BETWEEN 1 AND 4),

        CONSTRAINT CK_DimDate_DayOfWeek
            CHECK (DayOfWeekNumber BETWEEN 1 AND 7)
    );

    PRINT N'Đã tạo dwh.DimDate.';
END;
GO


/*============================================================
  2. DIM TIME
  Grain: one row per minute
============================================================*/

IF OBJECT_ID(N'dwh.DimTime', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimTime
    (
        TimeKey
            INT NOT NULL,

        FullTime
            TIME(0) NOT NULL,

        [Hour]
            TINYINT NOT NULL,

        [Minute]
            TINYINT NOT NULL,

        TimeBand
            NVARCHAR(20) NOT NULL,

        CONSTRAINT PK_DimTime
            PRIMARY KEY (TimeKey),

        CONSTRAINT UQ_DimTime_FullTime
            UNIQUE (FullTime),

        CONSTRAINT CK_DimTime_Hour
            CHECK ([Hour] BETWEEN 0 AND 23),

        CONSTRAINT CK_DimTime_Minute
            CHECK ([Minute] BETWEEN 0 AND 59),

        CONSTRAINT CK_DimTime_Band
            CHECK (
                TimeBand IN (
                    N'Night',
                    N'Morning',
                    N'Afternoon',
                    N'Evening'
                )
            )
    );

    PRINT N'Đã tạo dwh.DimTime.';
END;
GO


/*============================================================
  3. DIM LOCATION
  Grain: one row per official ONS district
============================================================*/

IF OBJECT_ID(N'dwh.DimLocation', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimLocation
    (
        LocationKey
            INT IDENTITY(1,1) NOT NULL,

        LocalAuthorityCode
            VARCHAR(20) NOT NULL,

        LocalAuthorityName
            NVARCHAR(150) NOT NULL,

        CONSTRAINT PK_DimLocation
            PRIMARY KEY (LocationKey),

        CONSTRAINT UQ_DimLocation_Code
            UNIQUE (LocalAuthorityCode)
    );

    PRINT N'Đã tạo dwh.DimLocation.';
END;
GO


/*============================================================
  4. DIM ROAD
  Grain: one distinct road-attribute combination
============================================================*/

IF OBJECT_ID(N'dwh.DimRoad', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimRoad
    (
        RoadKey
            INT IDENTITY(1,1) NOT NULL,

        FirstRoadClass
            NVARCHAR(100) NOT NULL,

        RoadType
            NVARCHAR(150) NOT NULL,

        SpeedLimit
            SMALLINT NULL,

        UrbanOrRuralArea
            NVARCHAR(100) NOT NULL,

        CONSTRAINT PK_DimRoad
            PRIMARY KEY (RoadKey),

        CONSTRAINT CK_DimRoad_SpeedLimit
            CHECK (
                SpeedLimit IS NULL
                OR SpeedLimit IN (20, 30, 40, 50, 60, 70)
            )
    );

    PRINT N'Đã tạo dwh.DimRoad.';
END;
GO


/*============================================================
  5. DIM JUNCTION
  Grain: one distinct junction-attribute combination
============================================================*/

IF OBJECT_ID(N'dwh.DimJunction', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimJunction
    (
        JunctionKey
            INT IDENTITY(1,1) NOT NULL,

        JunctionDetail
            NVARCHAR(200) NOT NULL,

        JunctionControl
            NVARCHAR(200) NOT NULL,

        PedestrianCrossing
            NVARCHAR(250) NOT NULL,

        CONSTRAINT PK_DimJunction
            PRIMARY KEY (JunctionKey)
    );

    PRINT N'Đã tạo dwh.DimJunction.';
END;
GO


/*============================================================
  6. DIM ENVIRONMENT
  Grain: one distinct environment combination
============================================================*/

IF OBJECT_ID(N'dwh.DimEnvironment', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimEnvironment
    (
        EnvironmentKey
            INT IDENTITY(1,1) NOT NULL,

        LightConditions
            NVARCHAR(200) NOT NULL,

        WeatherConditions
            NVARCHAR(200) NOT NULL,

        RoadSurfaceConditions
            NVARCHAR(200) NOT NULL,

        CONSTRAINT PK_DimEnvironment
            PRIMARY KEY (EnvironmentKey)
    );

    PRINT N'Đã tạo dwh.DimEnvironment.';
END;
GO


/*============================================================
  7. DIM VEHICLE
  Grain: one distinct vehicle-attribute combination
============================================================*/

IF OBJECT_ID(N'dwh.DimVehicle', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimVehicle
    (
        VehicleKey
            INT IDENTITY(1,1) NOT NULL,

        VehicleType
            NVARCHAR(250) NOT NULL,

        VehicleManoeuvre
            NVARCHAR(250) NOT NULL,

        SkiddingAndOverturning
            NVARCHAR(250) NOT NULL,

        VehicleLeavingCarriageway
            NVARCHAR(250) NOT NULL,

        CONSTRAINT PK_DimVehicle
            PRIMARY KEY (VehicleKey)
    );

    PRINT N'Đã tạo dwh.DimVehicle.';
END;
GO


/*============================================================
  8. DIM DRIVER
  Grain: one distinct driver-profile combination
============================================================*/

IF OBJECT_ID(N'dwh.DimDriver', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimDriver
    (
        DriverKey
            INT IDENTITY(1,1) NOT NULL,

        SexOfDriver
            NVARCHAR(100) NOT NULL,

        AgeBandOfDriver
            NVARCHAR(100) NOT NULL,

        CONSTRAINT PK_DimDriver
            PRIMARY KEY (DriverKey)
    );

    PRINT N'Đã tạo dwh.DimDriver.';
END;
GO


/*============================================================
  9. DIM CASUALTY
  Grain: one distinct casualty-profile combination
============================================================*/

IF OBJECT_ID(N'dwh.DimCasualty', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimCasualty
    (
        CasualtyKey
            INT IDENTITY(1,1) NOT NULL,

        CasualtyClass
            NVARCHAR(100) NOT NULL,

        SexOfCasualty
            NVARCHAR(100) NOT NULL,

        AgeBandOfCasualty
            NVARCHAR(100) NOT NULL,

        CasualtyType
            NVARCHAR(250) NOT NULL,

        CONSTRAINT PK_DimCasualty
            PRIMARY KEY (CasualtyKey)
    );

    PRINT N'Đã tạo dwh.DimCasualty.';
END;
GO


/*============================================================
  10. DIM COLLISION SEVERITY
  Grain: one collision-severity category
============================================================*/

IF OBJECT_ID(N'dwh.DimCollisionSeverity', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimCollisionSeverity
    (
        CollisionSeverityKey
            INT IDENTITY(1,1) NOT NULL,

        CollisionSeverity
            NVARCHAR(50) NOT NULL,

        CollisionSeverityGroup
            NVARCHAR(20) NOT NULL,

        CONSTRAINT PK_DimCollisionSeverity
            PRIMARY KEY (CollisionSeverityKey),

        CONSTRAINT UQ_DimCollisionSeverity
            UNIQUE (CollisionSeverity),

        CONSTRAINT CK_DimCollisionSeverity_Group
            CHECK (
                CollisionSeverityGroup
                IN (N'KSI', N'Non-KSI')
            )
    );

    PRINT N'Đã tạo dwh.DimCollisionSeverity.';
END;
GO


/*============================================================
  11. DIM CASUALTY SEVERITY
  Grain: one casualty-severity category
============================================================*/

IF OBJECT_ID(N'dwh.DimCasualtySeverity', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.DimCasualtySeverity
    (
        CasualtySeverityKey
            INT IDENTITY(1,1) NOT NULL,

        CasualtySeverity
            NVARCHAR(50) NOT NULL,

        CasualtySeverityGroup
            NVARCHAR(20) NOT NULL,

        CONSTRAINT PK_DimCasualtySeverity
            PRIMARY KEY (CasualtySeverityKey),

        CONSTRAINT UQ_DimCasualtySeverity
            UNIQUE (CasualtySeverity),

        CONSTRAINT CK_DimCasualtySeverity_Group
            CHECK (
                CasualtySeverityGroup
                IN (N'KSI', N'Non-KSI')
            )
    );

    PRINT N'Đã tạo dwh.DimCasualtySeverity.';
END;
GO