<%@ Page Language="C#" AutoEventWireup="true" CodeFile="LogOn.aspx.cs" Inherits="LogOn" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<!DOCTYPE html>
<html lang="en">

<head>
  <title>Nutanix 1 Click Demo</title>

  <!-- Meta -->
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta name="description" content="Nutanix Installer">

  <!-- Prevent cache -->
  <meta http-equiv="pragma" content="no-cache">
  <meta http-equiv="expires" content="-1">

  <!-- Compatibility Mode -->
  <meta http-equiv="X-UA-Compatible" content="IE=9; IE=8; IE=7; IE=EDGE" />
  <script src="app-extension/scripts/jquery.min.js"></script>
    <script type="text/javascript">
   var auto_refresh = setInterval(
   function ()
   {
   $('#n-content-wrapper').load('#n-content-wrapper');
   }, 500000); // refresh every 50000 milliseconds
  </script>

<script>
/* Set the width of the side navigation to 250px and the left margin of the page content to 250px and add a black background color to body */
function openNav() {
  document.getElementById("mySidenav").style.width = "250px";
  document.getElementById("main").style.marginLeft = "250px";
  document.body.style.backgroundColor = "rgba(0,0,0,0.4)";
}

/* Set the width of the side navigation to 0 and the left margin of the page content to 0, and the background color of body to white */
function closeNav() {
  document.getElementById("mySidenav").style.width = "0";
  document.getElementById("main").style.marginLeft = "0";
  document.body.style.backgroundColor = "white";
}
</script>

<script type="text/javascript">
// Popup window code
function newPopup(url) {
  popupWindow = window.open(
    url,'popUpWindow','height=300,width=400,left=10,top=10,resizable=yes,scrollbars=yes,toolbar=yes,menubar=no,location=no,directories=no,status=yes')
}
</script>


  <meta name="theme-color" content="#e3e3e3">

  <link href="app/styles/bootstrapb439.css" rel="stylesheet" />

  <link href="app/styles/antiscrollb439.css" rel="stylesheet" />

  <link href="app/styles/nutanix.minb439.css" rel="stylesheet" />


<style>
#n-header { 
  position: sticky; top: 0; 
  background:#343537; 
  z-index: 1000;
}


#divmies {
  top: 68px;
}
img.sticky {
  position: -webkit-sticky;
  position: sticky;
  top: 68px;
  left: 5px;
  width: 150px;
}
.sidenav {
  height: 100%;
  width: 0;
  position: fixed;
  z-index: 999;
  top: 50PX;
  left: 0;
  background-color: #343537;
  overflow-x: hidden;
  transition: 0.5s;
  padding-top: 60px;
}

.sidenav a {
  padding: 8px 8px 8px 32px;
  text-decoration: none;
  font-size: 18px;
  color: #818181;
  display: block;
  transition: 0.3s;
}

.sidenav a:hover {
  color:  #C6C5CC;
}

.sidenav .closebtn {
  position: absolute;
  top: 0;
  right: 5px;
  font-size: 36px;
  margin-left: 50px;
}

@media screen and (max-height: 450px) {
  .sidenav {padding-top: 15px;}
  .sidenav a {font-size: 18px;}
}
</style>
</head>






<body class="n-body-active"><div id="n-content-wrapper"><!-- Content

================================================== -->

<!-- Main navigation bar and page wrapper
================================================== -->

<div id="mySidenav" class="sidenav">
  <a href="javascript:void(0)" class="closebtn" onclick="closeNav()">&times;</a>
  <a href="Landing.ps1x">Welcome</a>
  <a href="EditQueue.ps1x">New Entry</a>
  <a href="Queued.ps1x">Queue</a>
  <a href="Running.ps1x">Live Status</a>
  <a href="Backups.ps1x">BluePrint Backups</a>
  <a href="History.ps1x">History</a>
  <a href="Stats.ps1x?filters=1Week">Statistics</a>
  <a href="Downloads.ps1x">Downloads</a>
  <a href="Help.ps1x">Help</a>
</div>
<div class="container-fluid">

  <!-- Notification Message
  ================================================== -->
  <div id="n-ctr-notification">
    <!-- @view: Notification view goes here... -->
  </div>

  <!-- Header
  ================================================== -->
  <div id="n-header" class="header" data-test="header" style="opacity:10.10";>

   

    <div class="n-navigation"  align="left">

      <div class="left-menu">

        <!-- Foundation Navigation steps
        ============================================= -->
        <div class="config-nav-container">
          <ul class="foundation-config-nav">





            <li navsubview="start" class="start-cfg" data-test="start-cfg" ;" style="display: inline-block;">
       
            </li> 


            
           </ul>

        </div>

      </div>

    </div>
  </div>
 <Br>
  <!-- Body Content
  ================================================== -->

     <img src="images/ntnxLogo.png" align="right" height="200" width="200"> <br>
  <div id="bodyContent" class="n-body-content" style="display: block;width: 85%;margin:0 auto;">
    <div id="stateContainer" class="n-state-container">
    <form id="form1" runat="server">
        <div>
            <b><center>Use Okta / AD Credentials to sign in.</b>
            <table align="center" id="table2" style="margin-top: 50px">
            
                <tr>
                    <td style="width: 113px; height: 20px">
                        Domain</td>
                    <td style="width: 235px; height: 20px;">
                        <asp:TextBox ID="txtDomain" runat="server" CssClass="borde-form" Width="248px"></asp:TextBox>
                        <asp:RequiredFieldValidator ID="rfvDomain" runat="server" ControlToValidate="txtDomain"
                            ErrorMessage="Required Field"></asp:RequiredFieldValidator>
                    </td>
                </tr>
                <tr>
                    <td style="width: 113px; height: 20px">
                        User</td>
                    <td style="width: 235px; height: 20px;">
                        <asp:TextBox ID="txtUser" runat="server" CssClass="borde-form" Width="248px"></asp:TextBox>
                        <asp:RequiredFieldValidator ID="rfvUsuario" runat="server" ControlToValidate="txtUser"
                            ErrorMessage="Required Field"></asp:RequiredFieldValidator>
                    </td>
                </tr>
                <tr>
                    <td height="20" style="width: 113px">
                        Password</td>
                    <td height="20" style="width: 235px">
                        <asp:TextBox ID="txtPassword" runat="server" CssClass="borde-form" TextMode="Password"
                            Width="248px"></asp:TextBox>
                            <asp:RequiredFieldValidator ID="rfvPassword" runat="server" ControlToValidate="txtPassword"
                            ErrorMessage="Required Field"></asp:RequiredFieldValidator>
                    </td>
                </tr>
                <tr>
                    <td height="20" style="width: 113px">
                        Okta Response</td>
                    <td height="20" style="width: 235px">
                        <asp:TextBox ID="fake" runat="server" CssClass="borde-form" TextMode="Password"
                            Width="248px"></asp:TextBox>

                    </td>
                </tr>
                <tr>
                    <td colspan="2" align="center">
                        <asp:label ID="lblError" runat="server" Visible="False" ForeColor="Red"/>
                    </td>
                </tr>
                <tr>
                    <td colspan="2" align="center">
                        <asp:Button ID="btnLogon" runat="server" Text="Logon" OnClick="btnLogon_Click" />
                    </td>
                </tr>
            </table>
        </div>
    </form>
</body>
</html>
