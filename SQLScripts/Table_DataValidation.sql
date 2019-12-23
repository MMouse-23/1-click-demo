USE [1ClickDemo]
GO

/****** Object:  Table [dbo].[DataValidation]    Script Date: 15-10-2019 00:07:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DataValidation](
	[QueueUUID] [varchar](max) NULL,
	[DateCreated] [datetime] NULL,
	[ERA_Validated] [int] NULL,
	[ERA_Result] [text] NULL,
	[Calm_Validated] [int] NULL,
	[Calm_Result] [text] NULL,
	[Karbon_Validated] [int] NULL,
	[Karbon_Result] [text] NULL,
	[Core_Validated] [int] NULL,
	[Core_Result] [text] NULL,
	[Files_Validated] [int] NULL,
	[Files_Result] [text] NULL,
	[Objects_Validated] [int] NULL,
	[Objects_Result] [text] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


