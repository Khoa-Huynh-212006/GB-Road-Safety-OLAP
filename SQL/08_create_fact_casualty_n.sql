USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
GO


/*============================================================
  FACT CASUALTY

  Grain:
  One row per casualty in one collision,
  linked to one involved vehicle.

  Expected row count after loading: 652,821
============================================================*/

IF OBJECT_ID(N'dwh.FactCasualty', N'U') IS NULL
BEGIN
    CREATE TABLE dwh.FactCasualty
    (
        /*----------------------------------------------------
          SURROGATE PRIMARY KEY
        ----------------------------------------------------*/

        FactCasualtyKey
            BIGINT IDENTITY(1,1) NOT NULL,


        /*----------------------------------------------------
          DIMENSION FOREIGN KEYS

          Foreign key constraints will be added
          after the Fact has been loaded and validated.
        ----------------------------------------------------*/

        DateKey
            INT NOT NULL,

        TimeKey
            INT NOT NULL,

        LocationKey
            INT NOT NULL,

        RoadKey
            INT NOT NULL,

        JunctionKey
            INT NOT NULL,

        EnvironmentKey
            INT NOT NULL,

        CollisionSeverityKey
            INT NOT NULL,

        VehicleKey
            INT NOT NULL,

        DriverKey
            INT NOT NULL,

        CasualtyKey
            INT NOT NULL,

        CasualtySeverityKey
            INT NOT NULL,


        /*----------------------------------------------------
          DEGENERATE DIMENSIONS / SOURCE REFERENCES
        ----------------------------------------------------*/

        CollisionIndex
            VARCHAR(50) NOT NULL,

        VehicleReference
            INT NOT NULL,

        CasualtyReference
            INT NOT NULL,

        VehicleInvolvementID
            VARCHAR(100) NOT NULL,


        /*----------------------------------------------------
          MAP COORDINATES

          Coordinates belong to the collision event.
          They are kept in Fact for Power BI maps.
        ----------------------------------------------------*/

        Longitude
            DECIMAL(9,6) NULL,

        Latitude
            DECIMAL(9,6) NULL,


        /*----------------------------------------------------
          ADDITIVE MEASURES
        ----------------------------------------------------*/

        CasualtyCount
            TINYINT NOT NULL
            CONSTRAINT DF_FactCasualty_CasualtyCount
            DEFAULT (1),

        KSICasualtyCount
            TINYINT NOT NULL,


        /*----------------------------------------------------
          CONSTRAINTS
        ----------------------------------------------------*/

        CONSTRAINT PK_FactCasualty
            PRIMARY KEY CLUSTERED (FactCasualtyKey),

        CONSTRAINT CK_FactCasualty_CasualtyCount
            CHECK (CasualtyCount = 1),

        CONSTRAINT CK_FactCasualty_KSICount
            CHECK (KSICasualtyCount IN (0, 1)),

        CONSTRAINT CK_FactCasualty_CoordinatePair
            CHECK
            (
                (
                    Longitude IS NULL
                    AND Latitude IS NULL
                )
                OR
                (
                    Longitude IS NOT NULL
                    AND Latitude IS NOT NULL
                )
            )
    );

    PRINT N'Đã tạo dwh.FactCasualty.';
END
ELSE
BEGIN
    PRINT N'dwh.FactCasualty đã tồn tại.';
END;
GO