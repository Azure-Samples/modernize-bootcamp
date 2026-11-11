using System;
using System.Data.Entity;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    public interface IAuthService
    {
        Task<User> ValidateUserAsync(string userName, string password);
        string HashPassword(string password, string salt);
        string CreateSalt();
    }

    /// <summary>
    /// Password verification for the legacy membership-style user store.
    /// New hashes are PBKDF2-HMAC-SHA256; the original salted-SHA1 scheme survives as a
    /// verify-only path so existing rows keep working.
    /// </summary>
    /// <remarks>
    /// Stored hashes are NOT upgraded on login: <see cref="Models.User.PasswordHash"/> is
    /// [StringLength(40)] and the database is read-only for this upgrade. To finish the
    /// migration in a real deployment: (1) widen PasswordHash to >= 200 chars and the SQL
    /// column to match, (2) then either rehash on next successful login or force a password
    /// reset, (3) and only once every row is PBKDF2, delete the legacy SHA-1 verifier below.
    /// </remarks>
    public class AuthService : IAuthService
    {
        private const string Pbkdf2Prefix = "PBKDF2$";
        private const int Pbkdf2Iterations = 210_000;
        private const int Pbkdf2HashSize = 32;
        private const int LegacySha1HexLength = 40;

        private static readonly HashAlgorithmName Pbkdf2HashAlgorithm = HashAlgorithmName.SHA256;

        private readonly IStoreDbContextFactory _contextFactory;

        public AuthService(IStoreDbContextFactory contextFactory)
        {
            _contextFactory = contextFactory ?? throw new ArgumentNullException(nameof(contextFactory));
        }

        public async Task<User> ValidateUserAsync(string userName, string password)
        {
            if (string.IsNullOrWhiteSpace(userName) || string.IsNullOrEmpty(password))
            {
                return null;
            }

            User user;
            using (var context = _contextFactory.Create())
            {
                user = await context.Users.FirstOrDefaultAsync(u => u.UserName == userName);
            }

            if (user == null || !user.IsApproved)
            {
                return null;
            }

            return VerifyPassword(password, user.PasswordSalt, user.PasswordHash) ? user : null;
        }

        public string HashPassword(string password, string salt)
        {
            var saltBytes = DecodeSalt(salt);
            var hash = Rfc2898DeriveBytes.Pbkdf2(
                password,
                saltBytes,
                Pbkdf2Iterations,
                Pbkdf2HashAlgorithm,
                Pbkdf2HashSize);

            return $"{Pbkdf2Prefix}{Pbkdf2Iterations}${Convert.ToBase64String(saltBytes)}${Convert.ToBase64String(hash)}";
        }

        public string CreateSalt()
        {
            var buffer = new byte[16];
            RandomNumberGenerator.Fill(buffer);

            return Convert.ToBase64String(buffer);
        }

        private static bool VerifyPassword(string password, string salt, string storedHash)
        {
            if (string.IsNullOrEmpty(storedHash))
            {
                return false;
            }

            return IsLegacySha1Hash(storedHash)
                ? VerifyLegacySha1(password, salt, storedHash)
                : VerifyPbkdf2(password, storedHash);
        }

        // A base64 PBKDF2 payload can never be exactly 40 hex characters, so shape alone
        // discriminates the two stored formats and no marker column is needed.
        private static bool IsLegacySha1Hash(string storedHash)
        {
            if (storedHash.Length != LegacySha1HexLength)
            {
                return false;
            }

            foreach (var c in storedHash)
            {
                var isHex = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
                if (!isHex)
                {
                    return false;
                }
            }

            return true;
        }

        private static bool VerifyPbkdf2(string password, string storedHash)
        {
            if (!storedHash.StartsWith(Pbkdf2Prefix, StringComparison.Ordinal))
            {
                return false;
            }

            var segments = storedHash.Split('$');
            if (segments.Length != 4)
            {
                return false;
            }

            if (!int.TryParse(segments[1], NumberStyles.None, CultureInfo.InvariantCulture, out var iterations) ||
                iterations <= 0)
            {
                return false;
            }

            byte[] saltBytes;
            byte[] expectedHash;
            try
            {
                saltBytes = Convert.FromBase64String(segments[2]);
                expectedHash = Convert.FromBase64String(segments[3]);
            }
            catch (FormatException)
            {
                return false;
            }

            if (expectedHash.Length == 0)
            {
                return false;
            }

            var actualHash = Rfc2898DeriveBytes.Pbkdf2(
                password,
                saltBytes,
                iterations,
                Pbkdf2HashAlgorithm,
                expectedHash.Length);

            return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
        }

        // Verify-only: reproduces the original salted-SHA1 digest so pre-upgrade rows still
        // authenticate. Never call this to create a stored hash.
        private static bool VerifyLegacySha1(string password, string salt, string storedHash)
        {
            var bytes = Encoding.UTF8.GetBytes((salt ?? string.Empty) + password);
            var digest = Convert.ToHexString(SHA1.HashData(bytes));

            return string.Equals(digest, storedHash, StringComparison.OrdinalIgnoreCase);
        }

        private static byte[] DecodeSalt(string salt)
        {
            if (string.IsNullOrEmpty(salt))
            {
                return Array.Empty<byte>();
            }

            var buffer = new byte[salt.Length];

            return Convert.TryFromBase64String(salt, buffer, out var written)
                ? buffer.AsSpan(0, written).ToArray()
                : Encoding.UTF8.GetBytes(salt);
        }
    }
}
