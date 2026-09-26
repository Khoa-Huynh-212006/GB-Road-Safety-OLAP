USE STATS19_DW;
GO

IF OBJECT_ID(N'dw.FactCasualty', N'U') IS NULL
BEGIN
    CREATE TABLE dw.FactCasualty
    (
        FactCasualtyKey      BIGINT IDENTITY(1,1) NOT NULL,

        -- Khóa tự nhiên của một casualty trong collision
        CollisionID          VARCHAR(20) NOT NULL,
        CasualtyReference    INT         NOT NULL,

        -- Khóa ngoại tới các Dimension
        DateKey                 INT NOT NULL,
        TimeKey                 INT NOT NULL,
        RegionKey               INT NOT NULL,
        LocalAuthorityKey       INT NOT NULL,
        RoadKey                 INT NOT NULL,
        EnvironmentKey          INT NOT NULL,
        JunctionKey             INT NOT NULL,
        PedestrianContextKey    INT NOT NULL,
        CasualtyProfileKey      INT NOT NULL,
        VehicleProfileKey       INT NOT NULL,
        CasualtySeverityKey     INT NOT NULL,
        CollisionSeverityKey    INT NOT NULL,

        -- Measures
        CasualtyAge SMALLINT NULL,
        CasualtyCount TINYINT NOT NULL
            CONSTRAINT DF_FactCasualty_CasualtyCount DEFAULT (1),
        FatalFlag    TINYINT NOT NULL,
        SeriousFlag  TINYINT NOT NULL,
        SlightFlag   TINYINT NOT NULL,
        KSIFlag      TINYINT NOT NULL,

        CONSTRAINT PK_FactCasualty
            PRIMARY KEY (FactCasualtyKey),

        CONSTRAINT UQ_FactCasualty_NaturalKey
            UNIQUE (CollisionID, CasualtyReference),

        CONSTRAINT FK_FactCasualty_DimDate
            FOREIGN KEY (DateKey)
            REFERENCES dw.DimDate(DateKey),

        CONSTRAINT FK_FactCasualty_DimTime
            FOREIGN KEY (TimeKey)
            REFERENCES dw.DimTime(TimeKey),

        CONSTRAINT FK_FactCasualty_DimRegion
            FOREIGN KEY (RegionKey)
            REFERENCES dw.DimRegion(RegionKey),

        CONSTRAINT FK_FactCasualty_DimLocalAuthority
            FOREIGN KEY (LocalAuthorityKey)
            REFERENCES dw.DimLocalAuthority(LocalAuthorityKey),

        CONSTRAINT FK_FactCasualty_DimRoad
            FOREIGN KEY (RoadKey)
            REFERENCES dw.DimRoad(RoadKey),

        CONSTRAINT FK_FactCasualty_DimEnvironment
            FOREIGN KEY (EnvironmentKey)
            REFERENCES dw.DimEnvironment(EnvironmentKey),

        CONSTRAINT FK_FactCasualty_DimJunction
            FOREIGN KEY (JunctionKey)
            REFERENCES dw.DimJunction(JunctionKey),

        CONSTRAINT FK_FactCasualty_DimPedestrianContext
            FOREIGN KEY (PedestrianContextKey)
            REFERENCES dw.DimPedestrianContext(PedestrianContextKey),

        CONSTRAINT FK_FactCasualty_DimCasualtyProfile
            FOREIGN KEY (CasualtyProfileKey)
            REFERENCES dw.DimCasualtyProfile(CasualtyProfileKey),

        CONSTRAINT FK_FactCasualty_DimVehicleProfile
            FOREIGN KEY (VehicleProfileKey)
            REFERENCES dw.DimVehicleProfile(VehicleProfileKey),

        CONSTRAINT FK_FactCasualty_CasualtySeverity
            FOREIGN KEY (CasualtySeverityKey)
            REFERENCES dw.DimSeverity(SeverityKey),

        CONSTRAINT FK_FactCasualty_CollisionSeverity
            FOREIGN KEY (CollisionSeverityKey)
            REFERENCES dw.DimSeverity(SeverityKey),

        CONSTRAINT CK_FactCasualty_Flags
            CHECK
            (
                FatalFlag IN (0, 1)
                AND SeriousFlag IN (0, 1)
                AND SlightFlag IN (0, 1)
                AND KSIFlag IN (0, 1)
            ),

        CONSTRAINT CK_FactCasualty_CasualtyCount
            CHECK (CasualtyCount = 1)
    );
END;
GO

-- tạo index trên các foreign key của Fact
USE STATS19_DW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_DateKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_DateKey
        ON dw.FactCasualty(DateKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_TimeKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_TimeKey
        ON dw.FactCasualty(TimeKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_RegionKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_RegionKey
        ON dw.FactCasualty(RegionKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_LocalAuthorityKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_LocalAuthorityKey
        ON dw.FactCasualty(LocalAuthorityKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_RoadKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_RoadKey
        ON dw.FactCasualty(RoadKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_EnvironmentKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_EnvironmentKey
        ON dw.FactCasualty(EnvironmentKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_JunctionKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_JunctionKey
        ON dw.FactCasualty(JunctionKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_PedestrianContextKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_PedestrianContextKey
        ON dw.FactCasualty(PedestrianContextKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_CasualtyProfileKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_CasualtyProfileKey
        ON dw.FactCasualty(CasualtyProfileKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_VehicleProfileKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_VehicleProfileKey
        ON dw.FactCasualty(VehicleProfileKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_CasualtySeverityKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_CasualtySeverityKey
        ON dw.FactCasualty(CasualtySeverityKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.FactCasualty')
      AND name = N'IX_FactCasualty_CollisionSeverityKey')
    CREATE NONCLUSTERED INDEX IX_FactCasualty_CollisionSeverityKey
        ON dw.FactCasualty(CollisionSeverityKey);
GO