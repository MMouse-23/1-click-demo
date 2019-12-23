USE [1ClickDemo]
GO

/****** Object:  Table [dbo].[Logging]    Script Date: 15-10-2019 00:08:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Logging](
	[QueueUUID] [nvarchar](100) NOT NULL,
	[EntryIndex] [int] NULL,
	[EntryType] [varchar](max) NULL,
	[LogType] [varchar](max) NULL,
	[Debug] [varchar](max) NULL,
	[Date] [datetime] NULL,
	[Message] [varchar](max) NULL,
	[SlackLevel] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


