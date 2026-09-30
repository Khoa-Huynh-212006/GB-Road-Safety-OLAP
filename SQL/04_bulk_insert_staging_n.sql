USE RoadSafetyDWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/*============================================================
  VERIFY STAGING TABLES
============================================================*/

IF OBJECT_ID(N'stg.Collisions', N'U') IS NULL
    THROW 50001, N'Không tìm thấy bảng stg.Collisions.', 1;

IF OBJECT_ID(N'stg.Vehicles', N'U') IS NULL
    THROW 50002, N'Không tìm thấy bảng stg.Vehicles.', 1;

IF OBJECT_ID(N'stg.Casualties', N'U') IS NULL
    THROW 50003, N'Không tìm thấy bảng stg.Casualties.', 1;
GO


/*============================================================
  BULK INSERT ALL STAGING TABLES

  Nếu một file bị lỗi:
  - Toàn bộ transaction được rollback.
  - Không để lại trạng thái chỉ nạp thành công một phần.
  - Không in thông báo thành công giả.
============================================================*/

BEGIN TRY
    BEGIN TRANSACTION;

    /*--------------------------------------------------------
      Xóa dữ liệu staging của lần chạy trước
    --------------------------------------------------------*/

    TRUNCATE TABLE stg.Casualties;
    TRUNCATE TABLE stg.Vehicles;
    TRUNCATE TABLE stg.Collisions;


    /*--------------------------------------------------------
      1. LOAD COLLISIONS
    --------------------------------------------------------*/

    BULK INSERT stg.Collisions
    FROM 'D:\OLAP\Data\Processed\collisions_clean.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        KEEPNULLS,
        TABLOCK
    );


    /*--------------------------------------------------------
      2. LOAD VEHICLES
    --------------------------------------------------------*/

    BULK INSERT stg.Vehicles
    FROM 'D:\OLAP\Data\Processed\vehicles_clean.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        KEEPNULLS,
        TABLOCK
    );


    /*--------------------------------------------------------
      3. LOAD CASUALTIES
    --------------------------------------------------------*/

    BULK INSERT stg.Casualties
    FROM 'D:\OLAP\Data\Processed\casualties_clean.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        KEEPNULLS,
        TABLOCK
    );


    /*--------------------------------------------------------
      VALIDATE ROW COUNTS BEFORE COMMIT
    --------------------------------------------------------*/

    DECLARE @CollisionRows BIGINT;
    DECLARE @VehicleRows BIGINT;
    DECLARE @CasualtyRows BIGINT;

    SELECT
        @CollisionRows = COUNT_BIG(*)
    FROM stg.Collisions;

    SELECT
        @VehicleRows = COUNT_BIG(*)
    FROM stg.Vehicles;

    SELECT
        @CasualtyRows = COUNT_BIG(*)
    FROM stg.Casualties;


    IF @CollisionRows <> 513801
    BEGIN
        THROW 50011,
            N'Số dòng stg.Collisions không đúng kỳ vọng.',
            1;
    END;


    IF @VehicleRows <> 937265
    BEGIN
        THROW 50012,
            N'Số dòng stg.Vehicles không đúng kỳ vọng.',
            1;
    END;


    IF @CasualtyRows <> 652821
    BEGIN
        THROW 50013,
            N'Số dòng stg.Casualties không đúng kỳ vọng.',
            1;
    END;


    COMMIT TRANSACTION;

    PRINT N'Đã nạp thành công toàn bộ ba staging tables.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT N'BULK INSERT thất bại. Toàn bộ staging load đã được rollback.';

    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage;

    THROW;
END CATCH;
GO


