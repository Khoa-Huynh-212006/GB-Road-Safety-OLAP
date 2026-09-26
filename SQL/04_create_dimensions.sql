USE STATS19_DW;
GO

IF SCHEMA_ID(N'dw') IS NULL
    EXEC(N'CREATE SCHEMA dw');
GO

IF OBJECT_ID(N'dw.DimDate', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimDate
    (
        DateKey       INT          NOT NULL,
        FullDate      DATE         NULL,
        Day           TINYINT      NULL,
        DayOfWeek     NVARCHAR(20) NULL,
        DayOfWeekSort TINYINT      NULL,
        Month         NVARCHAR(20) NULL,
        Quarter       TINYINT      NULL,
        Year          SMALLINT     NULL,

        CONSTRAINT PK_DimDate PRIMARY KEY (DateKey),
        CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate)
    );
END;
GO

IF OBJECT_ID(N'dw.DimTimeBand', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimTimeBand
    (
        TimeBandKey  INT          IDENTITY(1,1) NOT NULL,
        TimeBand     NVARCHAR(50) NOT NULL,
        StartHour    TINYINT      NULL,
        EndHour      TINYINT      NULL,
        TimeBandSort TINYINT      NULL,

        CONSTRAINT PK_DimTimeBand PRIMARY KEY (TimeBandKey),
        CONSTRAINT UQ_DimTimeBand_TimeBand UNIQUE (TimeBand)
    );
END;
GO

IF OBJECT_ID(N'dw.DimTime', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimTime
    (
        TimeKey      INT          IDENTITY(1,1) NOT NULL,
        FullTime     TIME(0)      NULL,
        Hour         TINYINT      NULL,
        Minute       TINYINT      NULL,
        TimeBandKey  INT          NULL,

        CONSTRAINT PK_DimTime PRIMARY KEY (TimeKey),
        CONSTRAINT UQ_DimTime_FullTime UNIQUE (FullTime),
        CONSTRAINT FK_DimTime_DimTimeBand
            FOREIGN KEY (TimeBandKey)
            REFERENCES dw.DimTimeBand(TimeBandKey)
    );
END;
GO

IF OBJECT_ID(N'dw.DimRegion', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimRegion
    (
        RegionKey  INT IDENTITY(1,1) NOT NULL,
        RegionName NVARCHAR(100)     NOT NULL,

        CONSTRAINT PK_DimRegion PRIMARY KEY (RegionKey),
        CONSTRAINT UQ_DimRegion_RegionName UNIQUE (RegionName)
    );
END;
GO

IF OBJECT_ID(N'dw.DimLocalAuthority', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimLocalAuthority
    (
        LocalAuthorityKey  INT         IDENTITY(1,1) NOT NULL,
        LocalAuthorityCode VARCHAR(20) NOT NULL,

        CONSTRAINT PK_DimLocalAuthority PRIMARY KEY (LocalAuthorityKey),
        CONSTRAINT UQ_DimLocalAuthority_Code UNIQUE (LocalAuthorityCode)
    );
END;
GO

IF OBJECT_ID(N'dw.DimRoad', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimRoad
    (
        RoadKey        INT IDENTITY(1,1) NOT NULL,
        FirstRoadClass NVARCHAR(100) NULL,
        RoadType       NVARCHAR(100) NULL,
        SpeedLimitMph  SMALLINT      NULL,
        AreaType       NVARCHAR(50)  NULL,

        CONSTRAINT PK_DimRoad PRIMARY KEY (RoadKey)
    );
END;
GO

IF OBJECT_ID(N'dw.DimEnvironment', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimEnvironment
    (
        EnvironmentKey       INT IDENTITY(1,1) NOT NULL,
        LightConditions      NVARCHAR(150) NULL,
        WeatherConditions    NVARCHAR(150) NULL,
        RoadSurfaceConditions NVARCHAR(150) NULL,

        CONSTRAINT PK_DimEnvironment PRIMARY KEY (EnvironmentKey)
    );
END;
GO

IF OBJECT_ID(N'dw.DimJunction', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimJunction
    (
        JunctionKey        INT IDENTITY(1,1) NOT NULL,
        JunctionDetail     NVARCHAR(150) NULL,
        JunctionControl    NVARCHAR(150) NULL,
        PedestrianCrossing NVARCHAR(150) NULL,

        CONSTRAINT PK_DimJunction PRIMARY KEY (JunctionKey)
    );
END;
GO

IF OBJECT_ID(N'dw.DimSeverity', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimSeverity
    (
        SeverityKey  INT IDENTITY(1,1) NOT NULL,
        SeverityName NVARCHAR(50)     NOT NULL,

        CONSTRAINT PK_DimSeverity PRIMARY KEY (SeverityKey),
        CONSTRAINT UQ_DimSeverity_Name UNIQUE (SeverityName)
    );
END;
GO

IF OBJECT_ID(N'dw.DimPedestrianContext', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimPedestrianContext
    (
        PedestrianContextKey INT IDENTITY(1,1) NOT NULL,
        PedestrianLocation   NVARCHAR(150) NULL,
        PedestrianMovement   NVARCHAR(150) NULL,

        CONSTRAINT PK_DimPedestrianContext
            PRIMARY KEY (PedestrianContextKey)
    );
END;
GO

IF OBJECT_ID(N'dw.DimCasualtyProfile', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimCasualtyProfile
    (
        CasualtyProfileKey INT IDENTITY(1,1) NOT NULL,
        CasualtyAgeBand    NVARCHAR(100) NULL,
        CasualtySex        NVARCHAR(50)  NULL,
        CasualtyClass      NVARCHAR(100) NULL,
        CasualtyType       NVARCHAR(150) NULL,

        CONSTRAINT PK_DimCasualtyProfile
            PRIMARY KEY (CasualtyProfileKey)
    );
END;
GO

IF OBJECT_ID(N'dw.DimVehicleProfile', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimVehicleProfile
    (
        VehicleProfileKey          INT IDENTITY(1,1) NOT NULL,
        VehicleType                NVARCHAR(150) NULL,
        DriverAgeBand              NVARCHAR(100) NULL,
        DriverSex                  NVARCHAR(50)  NULL,
        VehicleManoeuvre           NVARCHAR(150) NULL,
        SkiddingAndOverturning     NVARCHAR(150) NULL,
        VehicleLeavingCarriageway  NVARCHAR(150) NULL,

        CONSTRAINT PK_DimVehicleProfile
            PRIMARY KEY (VehicleProfileKey)
    );
END;
GO

-- unique constraint
IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_DimRoad_BusinessKey'
)
    ALTER TABLE dw.DimRoad
    ADD CONSTRAINT UQ_DimRoad_BusinessKey
    UNIQUE (FirstRoadClass, RoadType, SpeedLimitMph, AreaType);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_DimEnvironment_BusinessKey'
)
    ALTER TABLE dw.DimEnvironment
    ADD CONSTRAINT UQ_DimEnvironment_BusinessKey
    UNIQUE (LightConditions, WeatherConditions, RoadSurfaceConditions);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_DimJunction_BusinessKey'
)
    ALTER TABLE dw.DimJunction
    ADD CONSTRAINT UQ_DimJunction_BusinessKey
    UNIQUE (JunctionDetail, JunctionControl, PedestrianCrossing);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_DimPedestrianContext_BusinessKey'
)
    ALTER TABLE dw.DimPedestrianContext
    ADD CONSTRAINT UQ_DimPedestrianContext_BusinessKey
    UNIQUE (PedestrianLocation, PedestrianMovement);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_DimCasualtyProfile_BusinessKey'
)
    ALTER TABLE dw.DimCasualtyProfile
    ADD CONSTRAINT UQ_DimCasualtyProfile_BusinessKey
    UNIQUE (CasualtyAgeBand, CasualtySex, CasualtyClass, CasualtyType);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_DimVehicleProfile_BusinessKey'
)
    ALTER TABLE dw.DimVehicleProfile
    ADD CONSTRAINT UQ_DimVehicleProfile_BusinessKey
    UNIQUE (
        VehicleType,
        DriverAgeBand,
        DriverSex,
        VehicleManoeuvre,
        SkiddingAndOverturning,
        VehicleLeavingCarriageway
    );
GO

-- Unknown member với key 0
USE STATS19_DW;
GO

-- DimDate dùng DateKey dạng YYYYMMDD, không dùng IDENTITY.
IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE DateKey = 0)
    INSERT INTO dw.DimDate
        (DateKey, FullDate, Day, DayOfWeek, DayOfWeekSort, Month, Quarter, Year)
    VALUES
        (0, NULL, NULL, N'Unknown', NULL, N'Unknown', NULL, NULL);
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimTimeBand WHERE TimeBandKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimTimeBand ON;

    INSERT INTO dw.DimTimeBand
        (TimeBandKey, TimeBand, StartHour, EndHour, TimeBandSort)
    VALUES
        (0, N'Unknown', NULL, NULL, 0);

    SET IDENTITY_INSERT dw.DimTimeBand OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimTime WHERE TimeKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimTime ON;

    INSERT INTO dw.DimTime
        (TimeKey, FullTime, Hour, Minute, TimeBandKey)
    VALUES
        (0, NULL, NULL, NULL, 0);

    SET IDENTITY_INSERT dw.DimTime OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimRegion WHERE RegionKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimRegion ON;
    INSERT INTO dw.DimRegion (RegionKey, RegionName)
    VALUES (0, N'Unknown');
    SET IDENTITY_INSERT dw.DimRegion OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimLocalAuthority WHERE LocalAuthorityKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimLocalAuthority ON;
    INSERT INTO dw.DimLocalAuthority (LocalAuthorityKey, LocalAuthorityCode)
    VALUES (0, 'UNKNOWN');
    SET IDENTITY_INSERT dw.DimLocalAuthority OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimRoad WHERE RoadKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimRoad ON;
    INSERT INTO dw.DimRoad
        (RoadKey, FirstRoadClass, RoadType, SpeedLimitMph, AreaType)
    VALUES
        (0, N'Unknown', N'Unknown', NULL, N'Unknown');
    SET IDENTITY_INSERT dw.DimRoad OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimEnvironment WHERE EnvironmentKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimEnvironment ON;
    INSERT INTO dw.DimEnvironment
        (EnvironmentKey, LightConditions, WeatherConditions, RoadSurfaceConditions)
    VALUES
        (0, N'Unknown', N'Unknown', N'Unknown');
    SET IDENTITY_INSERT dw.DimEnvironment OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimJunction WHERE JunctionKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimJunction ON;
    INSERT INTO dw.DimJunction
        (JunctionKey, JunctionDetail, JunctionControl, PedestrianCrossing)
    VALUES
        (0, N'Unknown', N'Unknown', N'Unknown');
    SET IDENTITY_INSERT dw.DimJunction OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimSeverity WHERE SeverityKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimSeverity ON;
    INSERT INTO dw.DimSeverity (SeverityKey, SeverityName)
    VALUES (0, N'Unknown');
    SET IDENTITY_INSERT dw.DimSeverity OFF;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM dw.DimPedestrianContext
    WHERE PedestrianContextKey = 0
)
BEGIN
    SET IDENTITY_INSERT dw.DimPedestrianContext ON;
    INSERT INTO dw.DimPedestrianContext
        (PedestrianContextKey, PedestrianLocation, PedestrianMovement)
    VALUES
        (0, N'Unknown', N'Unknown');
    SET IDENTITY_INSERT dw.DimPedestrianContext OFF;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM dw.DimCasualtyProfile
    WHERE CasualtyProfileKey = 0
)
BEGIN
    SET IDENTITY_INSERT dw.DimCasualtyProfile ON;
    INSERT INTO dw.DimCasualtyProfile
        (CasualtyProfileKey, CasualtyAgeBand, CasualtySex, CasualtyClass, CasualtyType)
    VALUES
        (0, N'Unknown', N'Unknown', N'Unknown', N'Unknown');
    SET IDENTITY_INSERT dw.DimCasualtyProfile OFF;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM dw.DimVehicleProfile
    WHERE VehicleProfileKey = 0
)
BEGIN
    SET IDENTITY_INSERT dw.DimVehicleProfile ON;
    INSERT INTO dw.DimVehicleProfile
        (VehicleProfileKey, VehicleType, DriverAgeBand, DriverSex,
         VehicleManoeuvre, SkiddingAndOverturning, VehicleLeavingCarriageway)
    VALUES
        (0, N'Unknown', N'Unknown', N'Unknown',
         N'Unknown', N'Unknown', N'Unknown');
    SET IDENTITY_INSERT dw.DimVehicleProfile OFF;
END;
GO

