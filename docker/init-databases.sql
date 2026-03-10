-- Initialize databases for IFX
-- This script runs on SQL Server container startup

-- Create BackgroundJobsDb for Hangfire
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BackgroundJobsDb')
BEGIN
    CREATE DATABASE BackgroundJobsDb;
    PRINT 'Created BackgroundJobsDb database';
END
GO

-- Create IFXDb if not exists (for completeness)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'IFXDb')
BEGIN
    CREATE DATABASE IFXDb;
    PRINT 'Created IFXDb database';
END
GO
