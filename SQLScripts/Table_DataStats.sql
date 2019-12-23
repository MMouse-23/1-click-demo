USE [1ClickDemo]
GO

/****** Object:  Table [dbo].[DataStats]    Script Date: 15-10-2019 00:06:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DataStats](
	[QueueUUID] [nvarchar](100) NOT NULL,
	[Status] [varchar](max) NULL,
	[Percentage] [varchar](max) NULL,
	[CurrentChapter] [varchar](max) NULL,
	[TotalChapters] [varchar](max) NULL,
	[DateCreated] [datetime] NULL,
	[DateStopped] [datetime] NULL,
	[POCName] [varchar](max) NULL,
	[PEClusterIP] [varchar](max) NULL,
	[PCClusterIP] [varchar](max) NULL,
	[ErrorCount] [int] NULL,
	[WarningCount] [int] NULL,
	[PSErrorCount] [int] NULL,
	[ERAFailureCount] [int] NULL,
	[PCInstallFailureCount] [int] NULL,
	[ThreadCount] [int] NULL,
	[BuildTime] [varchar](max) NULL,
	[Debug] [int] NULL,
	[SENAME] [varchar](max) NULL,
	[Sender] [varchar](max) NULL,
	[AOSVersion] [varchar](max) NULL,
	[AHVVersion] [varchar](max) NULL,
	[PCVersion] [varchar](max) NULL,
	[ObjectsVersion] [varchar](max) NULL,
	[CalmVersion] [varchar](max) NULL,
	[KarbonVersion] [varchar](max) NULL,
	[FilesVersion] [varchar](max) NULL,
	[NCCVersion] [varchar](max) NULL,
	[ERAVersion] [varchar](max) NULL,
	[XRayVersion] [varchar](max) NULL,
	[MoveVersion] [varchar](max) NULL,
	[VMsDeployed] [int] NULL,
	[GBsDeployed] [int] NULL,
	[GBsRAMUsed] [int] NULL,
	[CoreCap] [int] NULL,
	[MemCapGB] [int] NULL,
	[DiskCapGB] [int] NULL,
	[AnalyticsVersion] [varchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[QueueUUID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


