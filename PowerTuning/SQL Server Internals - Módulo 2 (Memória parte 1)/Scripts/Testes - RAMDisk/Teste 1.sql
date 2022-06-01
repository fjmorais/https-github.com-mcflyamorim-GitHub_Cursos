USE master
GO
DROP DATABASE IF EXISTS [TestHDD]
GO
DROP DATABASE IF EXISTS [TestSSD]
GO
DROP DATABASE IF EXISTS [TestDRAM]
GO


-- 1 - Montar unidade com Dataram RAMDisk
-- 2 - Abrir perfmon pra ver disk write bytes/sec 

CREATE DATABASE [TestHDD]
 ON  PRIMARY 
( NAME = N'TestHDD', FILENAME = N'D:\Temp\TestHDD.mdf' , SIZE = 1024KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'TestHDD_log', FILENAME = N'D:\Temp\TestHDD_log.ldf' , SIZE = 1024000KB , FILEGROWTH = 65536KB )
GO

CREATE DATABASE [TestSSD]
 ON  PRIMARY 
( NAME = N'TestSSD', FILENAME = N'C:\Temp\TestSSD.mdf' , SIZE = 1024KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'TestSSD_log', FILENAME = N'C:\Temp\TestSSD_log.ldf' , SIZE = 1024000KB , FILEGROWTH = 65536KB )
GO

CREATE DATABASE [TestDRAM]
 ON  PRIMARY 
( NAME = N'TestDRAM', FILENAME = N'E:\Temp\TestDRAM.mdf' , SIZE = 1024KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'TestDRAM_log', FILENAME = N'E:\Temp\TestDRAM_log.ldf' , SIZE = 1024000KB , FILEGROWTH = 65536KB )
GO
