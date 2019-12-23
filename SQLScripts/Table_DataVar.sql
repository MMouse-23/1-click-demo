USE [1ClickDemo]
GO

/****** Object:  Table [dbo].[DataVar]    Script Date: 15-10-2019 00:08:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DataVar](
	[QueueUUID] [nvarchar](100) NOT NULL,
	[DateCreated] [datetime] NULL,
	[DateStopped] [datetime] NULL,
	[PEClusterIP] [varchar](max) NULL,
	[SenderName] [varchar](max) NULL,
	[SenderEMail] [varchar](max) NULL,
	[PEAdmin] [varchar](max) NULL,
	[PEPass] [varchar](max) NULL,
	[debug] [int] NULL,
	[AOSVersion] [varchar](max) NULL,
	[PCVersion] [varchar](max) NULL,
	[Hypervisor] [varchar](max) NULL,
	[InfraSubnetmask] [varchar](max) NULL,
	[InfraGateway] [varchar](max) NULL,
	[DNSServer] [varchar](max) NULL,
	[POCname] [varchar](max) NULL,
	[PCmode] [int] NULL,
	[SystemModel] [varchar](max) NULL,
	[CVMIPs] [varchar](max) NULL,
	[Nw1Vlan] [varchar](max) NULL,
	[Nw2DHCPStart] [varchar](max) NULL,
	[Nw2Vlan] [varchar](max) NULL,
	[Nw2subnet] [varchar](max) NULL,
	[Nw2gw] [varchar](max) NULL,
	[Location] [varchar](max) NULL,
	[VersionMethod] [varchar](max) NULL,
	[VPNUser] [varchar](max) NULL,
	[VPNPass] [varchar](max) NULL,
	[VPNURL] [varchar](max) NULL,
	[SetupSSP] [varchar](max) NULL,
	[DemoLab] [int] NULL,
	[EnableFlow] [int] NULL,
	[DemoXenDeskT] [int] NULL,
	[EnableBlueprintBackup] [int] NULL,
	[InstallEra] [int] NULL,
	[InstallFrame] [int] NULL,
	[InstallMove] [int] NULL,
	[InstallXRay] [int] NULL,
	[InstallObjects] [int] NULL,
	[UpdateAOS] [int] NULL,
	[InstallBPPack] [int] NULL,
	[DemoExchange] [int] NULL,
	[InstallKarbon] [int] NULL,
	[DemoIISXPlay] [int] NULL,
	[InstallFiles] [int] NULL,
	[InstallSplunk] [int] NULL,
	[InstallHashiVault] [int] NULL,
	[Install1CD] [int] NULL,
	[Install3TierLAMP] [int] NULL,
	[Slackbot] [int] NULL,
	[Portable] [int] NULL,
	[Destroy] [int] NULL,
	[EnableEmail] [int] NULL,
	[RootPID] [int] NULL,
	[PreDestroyPass] [varchar](max) NULL,
	[VCenterIP] [varchar](max) NULL,
	[VCenterUser] [varchar](max) NULL,
	[VCenterPass] [varchar](max) NULL,
	[pcsidebin] [varchar](max) NULL,
	[pcsidemeta] [varchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[QueueUUID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


