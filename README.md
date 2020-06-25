# 1-Click-Demo




**Current Version 1.2.0.3*


## Introduction

> The 1-Click-Demo application installs all Nutanix products on a blanc Nutanix cluster.
> With Demo content, Unattended, repeatable, consistent results. 

> This repository contains the complete codebase for 1-Click-Demo.
> Together with its blueprint it forms one complete install package

> This includes:

- SQL Scripts
- Powershell Modules
- Binaries
- Blueprints
- Website(s) (API / FrontEnd)
- 1CD Blueprint
.
> This application requires an SQL database and IIS to be installed. See installation / blueprint section for more details.
> The website is an ugly rip and needs TCL. The API site is a lot cleaner.
> The website uses a 3rd party module 

## Release notes 1.2.0.0

**Fixes:**
- ERA 0.9 API fixes.
- Full era 1.3.0 support.
- Enhanced Code, still a lot garbage to clean.
- Citrix BluePrint Launch Fixed.
- XPlay IIS / Calm 3.0 Fixes, Old BP did not fire correctly anymore.
- Wait timer enhancements.
- SQL Stability.
- Portable Edition, broken startup.
- Postgres HA Stability.

**Features:**
- SQL AAG in ERA (based of a single node, 1-click how cool is that)
- Calm 3.0.0 Runbook Automation Windows Patching
- Full Oracle Clone.
- MySQL Clone
- Calm ERA BP Removed, but replaced with API Clones.
- Move 3.5.2
- Full auto versioning
- 5 Marketplace Apps Running (BPPack and < 2 nodes only.)
- ERA Moved to secondary network.

## Release notes 1.1.2.3

**Fixes:**
- Resilliency 1CD BP
- Error PC Download support.

## Release notes 1.1.2.2

**Fixes:**
- Karbon 2.0 New Version Scheme Fix.
- Karbon 2.0 PC API Port changed. (not required.) 
- Objects PE Cluster UUID fix
- CALM Projects Fixed ACP - Role Mapping
- XPlay fixed Alert Policy Mapping.
- 1CD BP updated for public Chocolatry changes
- Timer Fix in XenApp BP

**Features:**
- era:0 on 768GB RAM blocks will enable objects. (all is on by default)
- 1CD Auto Partial Extract.


## Release notes 1.1.2.1

**Fixes:**
- XenDesktop BP with special chars in admin name


## Release notes 1.1.2.0

**Fixes:**
- New Move API fixed
- LCM Karbon Fix (multiple loops disapeared on new PC version but still required to get to the latest Karbon.)
- More places with missing dots in HPOC emails

**Features:**
- 15 VM Double 3 Tier XenApp Blueprint, only launched on blocks with more than 768 GB ram, installed and configured on lower RAM blocks.

**Known Issues:**
- XenAPP BP is rather complex, we will update confluence and setup a recorded zoom meeting on how to use / demo / show features in CALM soon.
- XenAPP BP has a 2 hour runtime, The finish time has not changed, however, the validation will wait as long as the BP stops provisioning or errors out.


## Release notes 1.1.2.1

**Fixes:**
- Karbon 2.0 New Version Scheme Fix.
- Karbon 2.0 PC API Port changed. (not required.) 
- Objects PE Cluster UUID fix
- CALM Projects Fixed ACP - Role Mapping
- XPlay fixed Alert Policy Mapping.
- 1CD BP updated for public Chocolatry changes

**Features:**
- era:0 on 768GB RAM blocks will enable objects. (all is on by default)
- 1CD Auto Partial Extract.


## Release notes 1.1.1.4

**Fixes:**
- ERA 1.2.0 Support, ERA enhanced some parts of their design. This required code changes on 1CD side.
- Allowing average install time of 2 hours and 45 minutes for Admin control.

**Known Issues:**
- Karbon LCM meta file is broken, although it works eventually, it causes extra install loops. The initial LCM offering is Karbon 1.0.3, once 1.0.3 is installed LCM offers 1.0.4, this is causing a plus 30 minutes install time. Confirmed by hand. 

## Release notes 1.1.1.3

**Fixes:**
- Queue Manual sending finished emails, missing manual mail message.
- Missing 3 Node PC IPs.
- XRay 3.6.1 new URL structure.
- Better LCM Status messages. 

**Features:**
- ERA Low RAM, ERA Supports 384GB ram blocks, only Maria, PostGres and MySQL will be installed, including blueprint. Oracle, MSSQL and PostgresHA are disabled.


## Release notes 1.1.1.2

**Fixes:**
- Objects installed based on version / memory usage fix.
- Fixed Network 2 Failures, Network 2 failures should not terminate 1CD, secondary network is always optional.
- ERA Prosgres HA, as separate thread for performance.
- Fix Maria Retry for stability VMware (Only unstable on VMware lol, same code)

Features
- Ability to send on behalf of someone else (Email) 
- Ability to Terminate and Clean your own requests. (Website)
- Ability for Admin to terminate and clean other requests (Website)







## Release notes 1.1

**Fixes:**
- Locks based on IP
- Code enhancements on LCM, no more failure notifications unless there is an actual failure.
- Code enhancements on RAM limit system, Fixes broken links in EMAIL / Slack.
- Module Merge and Splits, Larger modules split in to multiple smaller, single modules merged in to LIB modules.
- Redesigned the projects module, updated projects wait till update is completed.
- Redesigned the projects module, Now multithreading.
- Fixed Load throttling on 1CD, 4 builds that are less then 80% completed are allowed, build time changes automatically.
- Added more granular notifications.
- Enhanced unattended maintenance.
- Terminate if networking setup fails
- Terminate if PC install fails > 5
- PostGres HA Fixed.

**Features:**
- BluePrint for 1CD CI / CD
- Added MarketPlace population.
- Added AHV / Vmware / Karbon / Calm (2.9) Provider support.
- Added Karbon - Files Write many combination.
- Added skeleton VMware. (ERA + Oracle, Move, XRAY, LCM, BluePrints, Crossplay)

**Notes**
- Minimal version raised to 5.11

**VMware Notes**
- VMware will be removed in the future, this is a one off build.
- Please submit debug:2 in the body of the email to use. 
- VMware will only run on HPOC, not on portable edition or blueprint. This relies on UNC shares.

**Known issues:**
- Increased build time, 2 hours AHV, 3 for VMware
- LCM takes 1 hour to complete, 5 larger updates currently
- Projects takes longer because of Karbon integration.
- Vmware is not super stable, whipe and restart if it fails.
-


## Release notes 1.0.1.2

**Updated Versions:**
- Move VMware is autodownload now, AHV is still manual and cannot be changed. PortalUX team is adding move for qcow download, this will be full auto download soon. 
- Added auto download VMware for all existing AHV auto downloads.

**Fixes:**
- More HPOC SMTP Body fixes, DNS and Gateway for RTP and new PHX sites.
- Fixed Data parsing for spawned threads, added Database dependency instead of queue file.

**Features:**
- Added Datastore Creation support, all AOS containers will also be created as datastores and mounted.
- Added Finalize VMware module, renames all the default entries for VMware.
- Added VMware Image service support, uploads all images to the VMware Datastore.
> Single node mode works alot like normal, with the exception of files and Objects, files is 1 node, Objects requires too many IPs in a small subnet. Keeping ERA and all its databases. There is no choice for having objects on a single node. 

**Known issues:**
- VMware build is incomplete, is work in progress. standby for a future release.
- Single node works very simular to multi nodes, with a few by design limitations. This also means its bound by the same memory limitation. ERA, Objects will be determined by the amount of ram being available. 

## Release notes 1.0.1.1

- Added support for single node HPOC. 

## Release notes 1.0.1

**Updated Versions:**

- File Analytics GA 2.0.0 Now auto versioning
- XRAY 3.5.0         	now auto versioning
- ERA 1.1.0.1        	Now auto versioning
- Move 3.2.0        
- Buckets 1.0.0			Auto Versioning
- AOS 5.11				Auto Versioning (5.10.4 minimal)
- PC XPlay Demo 5.11    Auto Versioning
- Windows 10 Image     	Manual Win Update August 2019
- MSSQL 2016         	Manual Win Update August 2019

**Fixes:**

- Failed validation e.g. Esx etc, was not beeing notified since the new slackbot.
- AOS Upgrade enabled while already at latest.
- Check Integer for Vlan Network 1
- LCM Module rebuild. Added more functions and cleaned the logic for faster remediation and better readable code.
- Portable edition / password reset / non HPOC physical blocks

**Features:**

- Objects support
> Were adding an Objects store, creating 100 Buckets and connecting the instance to the Active Directory. Keep in mind this is a 1.0 release, we are increasing build stability as we move along. Objects takes about 50 minutes to install. This is pushing the finish-line time for 1CD. Objects is included in the LCM auto versioning.

- AutoVersioning
> Added many auto versioning systems for the remainder that was left to be automated. Now only Move and 1 Frame iso require manual updates. All other On prem solutions auto update.

- Failure Handling
> Added more checks to failures. Flow, Objects 3 different factors. XPlay is GA, removed the sideload and unlock procedure, demo is still live and working. 

- Basic API
> API Interface to 1CD for HPOC is build. Just the V1 version of the API. Working with the HPOC team on this.
> API interface for Rx portal integration.
> 
> 5 Functions are exposed. Create, monitor, options help etc.

- Payload source
> Portable no longer requires local payload, 

1. Target Region:  www will choose dropbox
2. Local will use the VM payload.
3. HPOC is default for email

> At portable edition start the payload download can be ignored


**Known issues:**

Somehow 1CD still touches things others do not :slightly_smiling_face:
    Objects has a rather frequent timeout bug on an internal KeepAlive service.
    This results in different failures. including build, and directory service failures.
    Checks are added to show these errors, they seem to be block / performance related.
    Working with ENG to tackle and solve these issues.
    We released this version regardless as its a nice start. yet not stable.
    https://jira.nutanix.com/browse/ENG-247048
Objects will enable from AOS 5.10.6 and onwards, where PC is always 5.11 and onwards.


**New Notes:**

If the block has less then 768 GB ram but more than 450, set era:0 if you want Objects.
Smaller blocks do not support objects (yet)

**Previous Notes**

Please submit AOS 5.10.4 if you want both AOS upgrade demo and high performance 1CD.
In any other combination you will have a long run-time (Plus 90min e.g. 190min total) or no means of demonstrating AOS upgrade.

This is however impossible for HPOC, hence, demonstrating AOS upgrades requires you to disable files.
Files:0 this lowers the minimal version towards 5.9.

**Previous Known issues:**

Due to the lengthy process of upgrading both AOS and AHV the progress status on slack pings with the same low percentage in the beginning.
This is a known limitation of the percentage indicator, this is counting chapters. As that process is just 2 chapters. the progress seems slow.
Hence progress indicator is not time relative. (edited)

## Installation

> The installation is done using a Nutanix Calm BluePrint. 
> 
> This blueprint will be released on the 1.1.0 version of 1CD.



