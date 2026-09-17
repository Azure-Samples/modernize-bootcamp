using System;
using System.Data.Entity.SqlServer;

namespace eShopLite.StoreFx.Data
{
    /// <summary>
    /// Adds transient-fault handling on top of the Microsoft.Data.SqlClient provider registration.
    /// Azure SQL throttles and recycles connections as normal behaviour, and EF6 does not retry by
    /// default, so without this the app surfaces routine platform events as 500s.
    /// </summary>
    /// <remarks>
    /// <see cref="SqlAzureExecutionStrategy"/> is incompatible with user-initiated transactions.
    /// Nothing in this app opens one; if that changes, suspend the strategy around the transaction.
    /// </remarks>
    public class StoreDbConfiguration : MicrosoftSqlDbConfiguration
    {
        private const string MicrosoftSqlClientProvider = "Microsoft.Data.SqlClient";

        public StoreDbConfiguration()
        {
            SetExecutionStrategy(
                MicrosoftSqlClientProvider,
                () => new SqlAzureExecutionStrategy(maxRetryCount: 5, maxDelay: TimeSpan.FromSeconds(10)));
        }
    }
}
