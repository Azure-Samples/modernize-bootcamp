// ---------------------------------------------------------------------------
// WARNING: INTENTIONALLY INSECURE. Hand-rolled sign-in screen kept as the
// "before" state for the Entra ID migration workshop. Replaced by MSAL.
// ---------------------------------------------------------------------------

using eShopLite.AdminFx.Services;
using System;
using System.Configuration;
using System.Windows.Forms;

namespace eShopLite.AdminFx.Forms
{
    public partial class LoginForm : Form
    {
        private const int MaxAttempts = 3;

        private readonly LegacyAuthService _authService;
        private int _failedAttempts;

        public LoginForm(LegacyAuthService authService)
        {
            _authService = authService;

            InitializeComponent();

            var remembered = ConfigurationManager.AppSettings["RememberedUsername"];
            if (!string.IsNullOrEmpty(remembered))
            {
                txtUsername.Text = remembered;
                chkRemember.Checked = true;
                ActiveControl = txtPassword;
            }
        }

        private void btnLogin_Click(object sender, EventArgs e)
        {
            var username = txtUsername.Text.Trim();
            var password = txtPassword.Text;

            if (username.Length == 0 || password.Length == 0)
            {
                lblError.Text = "Username and password are required.";
                return;
            }

            if (!_authService.TryAuthenticate(username, password))
            {
                _failedAttempts++;

                if (_failedAttempts >= MaxAttempts)
                {
                    MessageBox.Show(this, "Too many failed sign-in attempts. The application will close.", "Sign In", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    DialogResult = DialogResult.Cancel;
                    Close();
                    return;
                }

                lblError.Text = string.Format("Invalid username or password. {0} attempt(s) remaining.", MaxAttempts - _failedAttempts);
                txtPassword.Clear();
                ActiveControl = txtPassword;
                return;
            }

            SaveRememberedUsername(chkRemember.Checked ? username : string.Empty);
            DialogResult = DialogResult.OK;
            Close();
        }

        // Writes the username straight back into the config file beside the exe.
        private static void SaveRememberedUsername(string username)
        {
            try
            {
                var configuration = ConfigurationManager.OpenExeConfiguration(ConfigurationUserLevel.None);
                var settings = configuration.AppSettings.Settings;

                if (settings["RememberedUsername"] == null)
                {
                    settings.Add("RememberedUsername", username);
                }
                else
                {
                    settings["RememberedUsername"].Value = username;
                }

                configuration.Save(ConfigurationSaveMode.Modified);
                ConfigurationManager.RefreshSection("appSettings");
            }
            catch (ConfigurationErrorsException)
            {
                // Ignored: the workshop machine may not allow writing next to the exe.
            }
        }
    }
}
