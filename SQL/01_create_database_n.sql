USE master;
GO

IF DB_ID(N'RoadSafetyDWH') IS NULL
BEGIN
    CREATE DATABASE RoadSafetyDWH;
    PRINT N'Đã tạo database RoadSafetyDWH.';
END
ELSE
BEGIN
    PRINT N'Database RoadSafetyDWH đã tồn tại.';
END;
GO
