-- Initialize databases for AuthSamples
-- This script runs on SQL Server container startup

-- Create BackgroundJobsDb for Hangfire
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BackgroundJobsDb')
BEGIN
    CREATE DATABASE BackgroundJobsDb;
    PRINT 'Created BackgroundJobsDb database';
END
GO

-- Create AuthSamplesDb if not exists (for completeness)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'AuthSamplesDb')
BEGIN
    CREATE DATABASE AuthSamplesDb;
    PRINT 'Created AuthSamplesDb database';
END
GO
