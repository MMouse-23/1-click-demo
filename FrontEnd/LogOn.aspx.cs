using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using UserAuthentication;

public partial class LogOn : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!Page.IsPostBack)
        {
            string domainUser = System.Security.Principal.WindowsIdentity.GetCurrent().Name;
            string[] paramsLogin = domainUser.Split('\\');

            txtDomain.Text = "corp.nutanix.com";
        }
    }
    protected void btnLogon_Click(object sender, EventArgs e)
    {
        try
        {
            this.AutenticateUser(txtDomain.Text, txtUser.Text, txtPassword.Text);
        }
        catch (Exception ex)
        {
            lblError.Text = ex.Message;
            lblError.Visible = true;
        }
    }

    private void AutenticateUser(string domainName, string userName, string password)
    {
        // Path to you LDAP directory server.
        // Contact your network administrator to obtain a valid path.


        string adPath = "LDAP://corp.nutanix.com"  ;
        ActiveDirectoryValidator adAuth = new ActiveDirectoryValidator(adPath);
        if (true == adAuth.IsAuthenticated(domainName, userName, password))
        {
            // Create the authetication ticket
            FormsAuthenticationTicket authTicket = new FormsAuthenticationTicket(1, userName, DateTime.Now, DateTime.Now.AddMinutes(60), false, "");
            // Now encrypt the ticket.
            string encryptedTicket = FormsAuthentication.Encrypt(authTicket);
            // Create a cookie and add the encrypted ticket to the
            // cookie as data.
            HttpCookie authCookie = new HttpCookie(FormsAuthentication.FormsCookieName, encryptedTicket);
            // Add the cookie to the outgoing cookies collection.
            HttpContext.Current.Response.Cookies.Add(authCookie);
            // Redirect the user to the originally requested page
            HttpContext.Current.Response.Redirect(FormsAuthentication.GetRedirectUrl(userName, false));
        }

        

    }
}
