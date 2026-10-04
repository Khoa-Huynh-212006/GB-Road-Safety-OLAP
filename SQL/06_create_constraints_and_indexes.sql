USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;


    /*========================================================
      1. FOREIGN KEYS: FACT → DIMENSIONS

      WITH CHECK:
      - SQL Server kiểm tra toàn bộ dữ liệu đang tồn tại.
      - Foreign key được đánh dấu trusted.
    ========================================================*/

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimDate'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimDate
        FOREIGN KEY (DateKey)
        REFERENCES dwh.DimDate(DateKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimTime'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimTime
        FOREIGN KEY (TimeKey)
        REFERENCES dwh.DimTime(TimeKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimLocation'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimLocation
        FOREIGN KEY (LocationKey)
        REFERENCES dwh.DimLocation(LocationKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimRoad'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimRoad
        FOREIGN KEY (RoadKey)
        REFERENCES dwh.DimRoad(RoadKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimJunction'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimJunction
        FOREIGN KEY (JunctionKey)
        REFERENCES dwh.DimJunction(JunctionKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimEnvironment'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimEnvironment
        FOREIGN KEY (EnvironmentKey)
        REFERENCES dwh.DimEnvironment(EnvironmentKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimCollisionSeverity'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimCollisionSeverity
        FOREIGN KEY (CollisionSeverityKey)
        REFERENCES dwh.DimCollisionSeverity(
            CollisionSeverityKey
        );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimVehicle'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimVehicle
        FOREIGN KEY (VehicleKey)
        REFERENCES dwh.DimVehicle(VehicleKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimDriver'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimDriver
        FOREIGN KEY (DriverKey)
        REFERENCES dwh.DimDriver(DriverKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimCasualty'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimCasualty
        FOREIGN KEY (CasualtyKey)
        REFERENCES dwh.DimCasualty(CasualtyKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_FactCasualty_DimCasualtySeverity'
    )
    BEGIN
        ALTER TABLE dwh.FactCasualty
        WITH CHECK
        ADD CONSTRAINT FK_FactCasualty_DimCasualtySeverity
        FOREIGN KEY (CasualtySeverityKey)
        REFERENCES dwh.DimCasualtySeverity(
            CasualtySeverityKey
        );
    END;


    /*========================================================
      2. UNIQUE INDEX FOR FACT NATURAL KEY

      Grain:
      One casualty reference inside one collision.
    ========================================================*/

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(
                N'dwh.FactCasualty'
            )
            AND name =
                N'UX_FactCasualty_NaturalKey'
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX
            UX_FactCasualty_NaturalKey
        ON dwh.FactCasualty
        (
            CollisionIndex,
            CasualtyReference
        );
    END;


    /*========================================================
      3. INDEXES FOR DIMENSION FOREIGN KEYS

      SQL Server automatically indexes Primary Keys,
      but does not automatically index Foreign Keys.
    ========================================================*/

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_DateKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_FactCasualty_DateKey
        ON dwh.FactCasualty(DateKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_TimeKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_FactCasualty_TimeKey
        ON dwh.FactCasualty(TimeKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_LocationKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_FactCasualty_LocationKey
        ON dwh.FactCasualty(LocationKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_RoadKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_FactCasualty_RoadKey
        ON dwh.FactCasualty(RoadKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_JunctionKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_FactCasualty_JunctionKey
        ON dwh.FactCasualty(JunctionKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_EnvironmentKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_EnvironmentKey
        ON dwh.FactCasualty(EnvironmentKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name =
                N'IX_FactCasualty_CollisionSeverityKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_CollisionSeverityKey
        ON dwh.FactCasualty(CollisionSeverityKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_VehicleKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_VehicleKey
        ON dwh.FactCasualty(VehicleKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_DriverKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_DriverKey
        ON dwh.FactCasualty(DriverKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name = N'IX_FactCasualty_CasualtyKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_CasualtyKey
        ON dwh.FactCasualty(CasualtyKey);
    END;


    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name =
                N'IX_FactCasualty_CasualtySeverityKey'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_CasualtySeverityKey
        ON dwh.FactCasualty(CasualtySeverityKey);
    END;


    /*========================================================
      4. INDEX FOR DISTINCT VEHICLE COUNT
    ========================================================*/

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name =
                N'IX_FactCasualty_VehicleInvolvementID'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_VehicleInvolvementID
        ON dwh.FactCasualty(VehicleInvolvementID);
    END;


    /*========================================================
      5. FILTERED INDEX FOR POWER BI MAP

      Only indexes rows that have valid coordinates.
    ========================================================*/

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE
            object_id = OBJECT_ID(N'dwh.FactCasualty')
            AND name =
                N'IX_FactCasualty_Coordinates'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX
            IX_FactCasualty_Coordinates
        ON dwh.FactCasualty
        (
            Longitude,
            Latitude
        )
        WHERE
            Longitude IS NOT NULL
            AND Latitude IS NOT NULL;
    END;


    /*========================================================
      6. VERIFY FOREIGN KEYS
    ========================================================*/

    DECLARE @ForeignKeyCount INT;

    SELECT
        @ForeignKeyCount = COUNT(*)
    FROM sys.foreign_keys
    WHERE
        parent_object_id =
            OBJECT_ID(N'dwh.FactCasualty');


    IF @ForeignKeyCount <> 11
    BEGIN
        THROW 50301,
            N'FactCasualty không có đúng 11 foreign keys.',
            1;
    END;


    IF EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE
            parent_object_id =
                OBJECT_ID(N'dwh.FactCasualty')
            AND
            (
                is_disabled = 1
                OR is_not_trusted = 1
            )
    )
    BEGIN
        THROW 50302,
            N'Có foreign key bị disabled hoặc not trusted.',
            1;
    END;


    COMMIT TRANSACTION;

    PRINT N'Đã tạo thành công foreign keys và indexes.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT N'Tạo constraints/indexes thất bại. Transaction đã rollback.';

    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage;

    THROW;
END CATCH;
GO