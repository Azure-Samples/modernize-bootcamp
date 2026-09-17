using System.Data.Entity;
using System.Data.Entity.ModelConfiguration.Conventions;
using System.Data.Entity.SqlServer;
using System.Linq;

using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Data
{
    public interface IStoreDbContext
    {
        DbSet<Product> Products { get; set; }
        DbSet<StoreInfo> Stores { get; set; }
        DbSet<User> Users { get; set; }
        DbSet<Order> Orders { get; set; }
        DbSet<OrderLine> OrderLines { get; set; }

        OrderSummary GetOrderSummary(int userId);

        int SaveChanges();
    }

    // Replaces the <entityFramework><providers> registration that lived in the deleted Web.config.
    // EF6 does not auto-discover providers outside .NET Framework, and its in-box SqlProviderServices
    // binds to System.Data.SqlClient; MicrosoftSqlDbConfiguration wires up the Microsoft.Data.SqlClient
    // provider services, provider factory, and default connection factory instead.
    [DbConfigurationType(typeof(MicrosoftSqlDbConfiguration))]
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
        }

        public DbSet<Product> Products { get; set; }
        public DbSet<StoreInfo> Stores { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<Order> Orders { get; set; }
        public DbSet<OrderLine> OrderLines { get; set; }

        public OrderSummary GetOrderSummary(int userId)
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
                .Single();
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
