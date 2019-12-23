USE [1ClickDemo]
GO

/****** Object:  Table [dbo].[QueueInfo]    Script Date: 15-10-2019 00:08:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[QueueInfo](
	[ID] [decimal](18, 0) NULL,
	[QueueValue] [nvarchar](max) NULL,
	[Description] [nvarchar](max) NULL,
	[Required] [nvarchar](max) NULL,
	[AcceptedValues] [nvarchar](max) NULL,
	[Validation] [nvarchar](max) NULL,
	[ConfluenceLinkInt] [nvarchar](max) NULL,
	[ConfluenceLinkDemo] [nvarchar](max) NULL,
	[CLASS] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


