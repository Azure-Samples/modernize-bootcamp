# eShopLite — Connection String Setup

Open `src/eShopLite.StoreFx/Web.config` and replace the four placeholders in the connection string:

```xml
connectionString="Data Source=SERVER_NAME,1433;Initial Catalog=DATABASE_NAME;User ID=USER_ID;Password=PASSWORD_HERE;Encrypt=True;TrustServerCertificate=True;"
```

| Placeholder | Replace with |
| --- | --- |
| `SERVER_NAME` | The SQL Server address |
| `DATABASE_NAME` | The database name |
| `USER_ID` | The SQL login name |
| `PASSWORD_HERE` | The password for that login |

Leave the rest of the connection string unchanged.
