## Intial Database Setup

#### <u>These setps would have been completed before the labs start.</u>

1. Install [Sql Server Management Studio](https://learn.microsoft.com/en-us/ssms/install/install) on the VM.
2. Launch SSMS. 
3. In **Object Explorer**, right-click **Databases**, select **Import Data-tier Application**, and choose the `eshop.bacpac` file.
4. If you are using an Azure-provided SQL Server 2016 image on Windows Server 2016, the server might allow only Windows authentication—even if SQL authentication was selected during setup.
5. To enable SQL authentication, right-click **localhost** in SSMS and select **Properties**. Under **Security**, choose **SQL Server and Windows Authentication mode**.
6. Enabling SQL authentication does not automatically enable the `sa` login.
7. To enable it, expand **localhost** > **Security** > **Logins**, right-click **sa**, and select **Properties**. Under **Status**, set **Login** to **Enabled**, and update the password if necessary.


