using System;
using System.Data.Entity;
using System.Data.Entity.ModelConfiguration.Conventions;
using System.Data.Entity.SqlServer;
using System.Linq;
using System.Threading.Tasks;

using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Data
{
    public interface IStoreDbContext : IDisposable
    {
        DbSet<Product> Products { get; set; }
        DbSet<StoreInfo> Stores { get; set; }
        DbSet<User> Users { get; set; }
        DbSet<Order> Orders { get; set; }
        DbSet<OrderLine> OrderLines { get; set; }

        Task<OrderSummary> GetOrderSummaryAsync(int userId);

        Task<int> SaveChangesAsync();
    }

    /// <summary>
    /// Hands out a short-lived context per unit of work. Blazor Server scopes live as long as the
    /// circuit, so a scoped EF6 context would outlive the page that opened it and serve stale reads.
    /// </summary>
    public interface IStoreDbContextFactory
    {
        IStoreDbContext Create();
    }

    public sealed class StoreDbContextFactory : IStoreDbContextFactory
    {
        private readonly string _connectionString;

        public StoreDbContextFactory(string connectionString)
        {
            _connectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
        }

        public IStoreDbContext Create()
        {
            return new StoreDbContext(_connectionString);
        }
    }

    // Replaces the <entityFramework><providers> registration that lived in the deleted Web.config.
    // EF6 does not auto-discover providers outside .NET Framework, and its in-box SqlProviderServices
    // binds to System.Data.SqlClient; MicrosoftSqlDbConfiguration wires up the Microsoft.Data.SqlClient
    // provider services, provider factory, and default connection factory instead.
    [DbConfigurationType(typeof(StoreDbConfiguration))]
    public class StoreDbContext : DbContext, IStoreDbContext
    {
        // Required only by the EF6 migrations tooling: DbMigrationsConfiguration<TContext>
        // constrains TContext to new(). Never used at runtime - the host always supplies the
        // connection string from IConfiguration.
        public StoreDbContext() : base("StoreDbContext")
        {
        }

        public StoreDbContext(string connectionString) : base(connectionString)
        {
            // Entities outlive the context now that one is created per unit of work, so nothing may
            // depend on a live connection after materialization.
            Configuration.LazyLoadingEnabled = false;
            Configuration.ProxyCreationEnabled = false;
        }

        public DbSet<Product> Products { get; set; }
        public DbSet<StoreInfo> Stores { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<Order> Orders { get; set; }
        public DbSet<OrderLine> OrderLines { get; set; }

        public Task<OrderSummary> GetOrderSummaryAsync(int userId)
        {
            // [Order] is a reserved word; COUNT(*) guarantees exactly one row even with no orders.
            // @p0 is EF6's positional parameter name - passing the raw value lets EF create a
            // parameter of its own provider's type instead of coupling this file to a SqlClient.
            const string sql =
                "SELECT COUNT(*) AS OrderCount, ISNULL(SUM(Total), 0) AS LifetimeTotal, " +
                "MIN(PlacedUtc) AS FirstOrderUtc, MAX(PlacedUtc) AS LastOrderUtc " +
                "FROM [Order] WHERE UserId = @p0";

            return Database
                .SqlQuery<OrderSummary>(sql, userId)
                .SingleAsync();
        }

        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            modelBuilder.Conventions.Remove<PluralizingTableNameConvention>();

            modelBuilder.Entity<User>()
                .HasIndex(u => u.UserName)
                .IsUnique();

            modelBuilder.Entity<Order>()
                .HasMany(o => o.Lines)
                .WithRequired(l => l.Order)
                .HasForeignKey(l => l.OrderId)
                .WillCascadeOnDelete(true);
        }
    }
}
