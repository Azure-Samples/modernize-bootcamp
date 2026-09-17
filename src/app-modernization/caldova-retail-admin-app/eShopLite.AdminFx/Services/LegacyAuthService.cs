// ---------------------------------------------------------------------------
// WARNING: INTENTIONALLY INSECURE. This file exists to provide a realistic
// "legacy auth" starting point for a migration workshop. It stores unsalted
// SHA1 password hashes in a file next to the executable and keeps the signed-in
// user in global mutable state. Do not copy any of this into a real product.
// It is replaced by Microsoft Entra ID + MSAL later in the workshop.
// ---------------------------------------------------------------------------

using eShopLite.AdminFx.Models;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace eShopLite.AdminFx.Services
{
    public class LegacyAuthService
    {
        public static AppUser CurrentUser;

        private readonly string _usersFilePath;

        public LegacyAuthService(string usersFilePath)
        {
            _usersFilePath = usersFilePath;
        }

        public bool TryAuthenticate(string username, string password)
        {
            var users = LoadUsers();
            var attemptedHash = HashPassword(password);

            foreach (var user in users)
            {
                if (string.Equals(user.Username, username, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(user.PasswordHash, attemptedHash, StringComparison.OrdinalIgnoreCase))
                {
                    CurrentUser = user;
                    return true;
                }
            }

            return false;
        }

        public static string HashPassword(string password)
        {
            using (var sha1 = SHA1.Create())
            {
                var bytes = sha1.ComputeHash(Encoding.UTF8.GetBytes(password ?? string.Empty));
                var builder = new StringBuilder();

                for (var i = 0; i < bytes.Length; i++)
                {
                    builder.Append(bytes[i].ToString("x2"));
                }

                return builder.ToString();
            }
        }

        public static bool IsEditor()
        {
            return CurrentUser != null && string.Equals(CurrentUser.Role, "Editor", StringComparison.OrdinalIgnoreCase);
        }

        public static string DescribeCurrentUser()
        {
            if (CurrentUser == null)
            {
                return "Not signed in";
            }

            return string.Format("{0} ({1})", CurrentUser.Username, CurrentUser.Role);
        }

        public static void SignOut()
        {
            CurrentUser = null;
        }

        private IList<AppUser> LoadUsers()
        {
            if (!File.Exists(_usersFilePath))
            {
                return new List<AppUser>();
            }

            var json = File.ReadAllText(_usersFilePath);
            return JsonConvert.DeserializeObject<List<AppUser>>(json) ?? new List<AppUser>();
        }
    }
}
