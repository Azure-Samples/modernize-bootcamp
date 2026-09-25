using System;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace eShopLite.StoreFx.Services
{
    /// <summary>
    /// Readiness probe for the catalogue database. The previous endpoint returned "Healthy"
    /// unconditionally, so an instance that could not reach SQL still reported itself ready and
    /// kept receiving traffic.
    /// </summary>
    /// <remarks>
    /// Deliberately bypasses EF: going through the context inherits the retry strategy and the
    /// model build, which turned an unreachable server into a 45 second probe. A registration
    /// timeout cannot fix that on its own, because opening a SqlConnection does not observe the
    /// cancellation token while the TCP connect is outstanding - the connect timeout has to be
    /// short in the connection string itself.
    /// </remarks>
    public sealed class StoreDatabaseHealthCheck : IHealthCheck
    {
        private const int ConnectTimeoutSeconds = 3;

        private readonly string _connectionString;

        public StoreDatabaseHealthCheck(string connectionString)
        {
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new ArgumentException("Connection string is required.", nameof(connectionString));
            }

            _connectionString = new SqlConnectionStringBuilder(connectionString)
            {
                ConnectTimeout = ConnectTimeoutSeconds,
                // A probe must never queue behind saturated application connections.
                Pooling = false
            }.ConnectionString;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync(cancellationToken);

                    using (var command = connection.CreateCommand())
                    {
                        command.CommandText = "SELECT 1";
                        command.CommandTimeout = ConnectTimeoutSeconds;
                        await command.ExecuteScalarAsync(cancellationToken);
                    }
                }

                return HealthCheckResult.Healthy("Catalogue database reachable.");
            }
            catch (Exception ex)
            {
                return HealthCheckResult.Unhealthy("Catalogue database unreachable.", ex);
            }
        }
    }
}
