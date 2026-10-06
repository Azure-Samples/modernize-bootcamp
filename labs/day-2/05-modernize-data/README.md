# Lab 05: Database Modernization Bootcamp

## SQL Server to Azure SQL Database — Student Migration Challenges

**Scenario:** Migrate the eShop database from SQL Server on VM to Azure SQL Database by using Azure Database Migration Service (DMS).

Now that the application is upgraded and moved to Azure PaaS services, it is time to modernize and migrate the database. 

***Security rule:*** *Never expose passwords, storage keys, SAS tokens, or connection strings in screenshots or submissions. Do not enable public RDP or public Azure SQL access unless the instructor explicitly requires it.*

Learning objectives

Students will learn to:

* Gather information about a SQL server database
* Prepare and assess a SQL Server database for migration to Azure.
* Learn about diffenent authentication mechanisms in SQL server
* Learn about different types of backups and migration techniques
* Run an assessment of the source SQL Server database, analyze the report
* Use the managed database target selected during Lab 04.
* Configure private connectivity to the Azure SQL Database from both the Azure VM and also target PaaS services
* Create Azure Data Migration Service (DMS) and configure to run the "Self hosted Integration Runtime" on the Azure VM.
* Run DMS online migration to SQL MI and verify migration.
* Configure the application with the database FQDN exported by Lab 04.
* Document differences between Azre SQLDB and Azire SQL MI and lessons learned. 

## Challenge 1 — Validate the source database

### Student tasks

1. Using SQL Server Management Studio, connect to the source database using the instructor-approved method.
2. Confirm that SQL Server services are running on the source database VM - windows service named "SQL Server (MSSQLSERVER)"
3. Connect to the local SQL Server with SQL Server Management Studio (SSMS) using "sa" SQL login given to you
4. Record the SQL Server version,edition - right click on the server and type "new query". Execute the following SQL

```sql
Use master;
select @@version ;
```
5. Right click on database eshop and click on peroperties to determine database size, collation, disk file name and size of database files and "recovery mode", like [![this](./images/Challenge_1_db_properties.png)](./images/Challenge_1_db_properties.png)
6. While there, also note down all the "page" names displayed when checking on database "properties" section.
7. From the "Files" section, note down the data files and transaction log file name.
8. You connected to the SQL server using SQL authentication. What are other ways to authenticate to a SQL server?
9. (Research on this) What is a logical and physical backup of SQL database ?
10. How is recovery mode and logical and/or physical backup related ?
11. Put the database into full recovery mode in SSMS running this query

```sql
ALTER DATABASE
 eshop 
SET RECOVERY 
 full ;
```
12. Verify that the eshop database was placed in full recovery mode 

```sql
SELECT 
  name, recovery_model_desc 
FROM 
  sys.databases 
WHERE 
  name = 'eshop' ;
```

13. Run this query using SSMS. Investigate the results. Which table has the most number of rows ?

```text
DBCC CHECKDB (N'eShop') ;
```

## Success criteria

* SSMS connects to the source instance.
* The student records the source version, edition, size etc.
* You can explain at least four different authentication mechanisms and show at least two ways to connnect
* You can explain recovery model and different types of backups.

## Challenge 2 — Pre-migration assessment of the source database 

SSMS 22 is the latest version of Microsoft’s SQL Server Management Studio, a 64-bit graphical tool for managing, developing, and administering SQL Server and Azure databases. We will use it in the lab to perform the database assessment, querying and performing the necessary backups to upload to Azure storage for the migration. To launch the tool, locate on the labs desktop the shortcut:

 ![SSMS](./images/ssms_22.png)

The Azure SQL Managed Instance configured in this lab is configured to authenticate using <u>Entra only.</u> Notice that there are several ways you can authenticate to SQL server using Entra. In this lab, you must select authentication method <b>Entra with Password.</b>  The public endpoint is used to connect from the virtual lab environment therefore when connecting using SSMS, port 3342 needs to be used. 

### Validate firewall access to SQL MI before begining.

 Validate from the portal, that the NSG for the VNet that Azure SQL Managed Instance is using is allowing inbount access to port 3342.  If not, add an inbound rule for port 3342. From the overview page of SQL MI, click on virtual network/subnet. On the subnet page, find the Network Security Group name. Pull up that NSG by name and add an imbound port rule like this:

 ![NSG1](./images/NSG1.png)

<<<<<<< HEAD
2- Select the right option in SSMS when loging in. To find out the Entra ID to use for login, navigate from the portal to the deployed Azure SQL Managed Instance and go to Microsoft Entra ID on the left.

![SQLMI_ENTRA](./images/sqlmi_entra.png)

To retrieve the public endpoint FQDN and port number to use as part of the connection information, navigate to the Azure SQL Managed Instance in the portal.  Go to *Connection strings* an lookup the public endpoint examples.

![AZSQLMIPE](./images/AzSQLMIPE.png)

=======
>>>>>>> 906f367 (minor fix, simplification till challenge 3 and part of 4)
Use that Entra ID to login using SSMS.

![SSMS_LOGIN](./images/ssms_login.png)

## Student tasks

1. Using SSMS, connect to the SQL Server 2016  that is is resides on a VM in this lab environment. The connection to "on-premises" SQL server is preconfigured in the lab. Right click on the server and choose "Migrate SQL Server"
 ![SSMS](./images/Challenge_2_assessment_launch_1.png)
2. <u>Do not Migrate or Upgrade the database</u>. Run a "Migration rediness assessment". An html file will open in your browser once the assessment completes. This is the report.
 ![SSMS](./images/Challenge_2_assessment_launch_2.png)
3. Investigate the report. Find out compatibility issues with different SQL targets ![Assessment](./images/Challenge_2_assessment_full_report.png)
4. Connect to the target SQL MI using SSMS. Select the right option in SSMS when loging in. To find out the Entra ID to use for login, navigate from the portal to the deployed Azure SQL Managed Instance and go to Microsoft Entra ID on the left under settings. In this lab, this Entra ID is same as your Azure login - also shared under <b>"Resources"</b> section on the top.

![SQLMI_ENTRA](./images/sqlmi_entra.png)


## Success criteria

* You learn how to run an assessment using SSMS 22.
* Understand the assessment report and the comptatibility issues.
* You are able to connect to the SQL MI from the lab VM.

## Challenge 3 — Create the required azure resources

Azure SQL Managed Instance, the target database service, is already provisioned on your lab subscription to save time. You will need to validate that *System Assigned Managed Identity* is enabled for the server.  

In this part of the lab you will create the necesary Azure resources to perform the migration. Deploy the resources in the same region that Azure SQL MI is deployed.  You will:

- Create a resource provider (if it does not exist) in the subscription for DMS.
- Deploy an Azure storage account and a blob container to store database and transaction log file backups.
- Deploy an Azure Database Migration Service (DMS) to migrate the database.


## Student tasks

### 1. Resource provider

From the Azure portal, go to *Subscriptions*.  Expand on settings. Click on *Ressource Providers* and confirm that *Microsoft.DataMigration* is registered.  If it is not, then register it.

![ResourceProvider](./images/dms_resource_provider.png)

### 2. Azure SQL MI System Assigned Managed Identity

Locate the pre-deployed Azure SQL Managed instance in your lab subscription. Go to the *Identity* blade under Security and confirm that *System Assigned Managed Identity* is enabled.  If it is not then enable it.

![SQLMI_SAMI](./images/SQLMI_SAMI.png)

### 3. Storage Account

Provision an Azure Storage Account <b>in the same region as your SQL MI </b>and create a Blob container in it to store source database backup. 

![Storage1](./images/Storage_1.png)
![Storage3](./images/Storage_3.png)

Once the storage account is created, you will need to grant to your current Azure user the permission to manage Blob containers.  Do this via IAM.  Assign the *Storage Blob Data Owner* role to your own Entra ID.

![Storage5](./images/Storage_5.png)
![Storage6](./images/Storage_6.png)
![Storage7](./images/Storage_7.png)
![Storage8](./images/Storage_8.png)

Similarly, you will need to grant permission so that the Managed Identity of the SQL MI can retrieve the backup, i.e. it has role "Storage Bolb Data Reader" role assigned. The identity has the same name as the SQL MI instance your lab subscription.

![Storage10](./images/Storage_10.png)

Create a Blob container in the storage account and a folder within the container.

![Storage11](./images/Storage_11.png)
![Storage12](./images/Storage_12.png)

### 4. Database Migration Service (DMS)

<b>In the same region where Azure SQL MI</b> is deployed in the lab subscription, deploy Azure Database Migration Services (DMS).

![DMS1](./images/DMS_1.png)

## Success criteria

- Resource provider is registered for data migrations
- SQL MI configured for System Assigned Managed Identity
- Storage account is created with a Blob container in it
- DMS is deployed in the same region as SQL MI


## Challenge 4 — Online Migraton to SQL Managed Instance

In this challenge you will perform database backups to the Azure Storage account provisioned earlier.  You will then use DMS to perform an *Online* migration. To perform and online migration, DMS restores backups then takes advantage of the *Log Replay Service* (LRS) to replay transaction logs and complete the migration. 

## Student tasks

### 1. Backup the database to Azure Storage using SSMS 22

Launch SSMS from the desktop:

 ![SSMS22](./images/ssms_22.png)

Connect to the source database that resides in the VM. Expand the tree and Database folder and locate the *eShop* database. Right click and select Tasks->Backup.

![SSMS22_1](./images/SSMS22_1.png)

Select *Full* for backup type and *URL* for *Back up to*. Click on *Add* to select the Azure Storage account and Blob container.

![SSMS22_2](./images/SSMS22_2.png)

Click on *New Container*

![SSMS22_3](./images/SSMS22_3.png)

Login to the lab's subscription and select the storage account and container created earlier. Generate SAS credentials and save them in notepad. Click OK.

![SSMS22_4](./images/SSMS22_4.png)

Note: DMS can restore a backup stored either in the root level of a container or inside a container - not any level further below it. Complete the backup - it should take less than a minute. 

![SSMS22_5](./images/SSMS22_5.png)

Repeat the task this time taking a differential backup instead of a full backup.

![SSMS22_6](./images/SSMS22_6.png)

The backups should be listed in the Blob container in the storage account.
Notice the size of the full and the differential backups. 

Do you think it is ever possible to have a differential backup larger than full backup ?

![SSMS22_7](./images/SSMS22_7.png)

### 2. Migrate the database online using DMS

Navigate to the Azure portal to the DMS service created earlier.  Select "New Migration"

![DMS_6](./images/DMS_1.png)

Next, choose the migration scenario - from Sql Server to Azure SQL MI.
Choose Blob as backup location and online as backup mode.

![DMS_7](./images/DMS_7.png)

Select *Blob Storage* as the location of the backup files and *Online* as the migration mode.


Configure details as shown. 

<b>Note: </b> that DMS needs to configure a SQL datanase to track progress of migration for restartability. What you are entering here is information for that tracking database - not your source or target database. You need not manage this instance for this lab. 

**Also note**

- This tracking database can be in a different region also. 
- Furthermore, if for some reason you want to try the migration again, you would need to provide a new tracking database name.


![DMS_8](./images/DMS_8.png)

Select the Azure SQL managed Instance that already exists as a target.

![DMS_9](./images/DMS_9.png)

Specify the location of the backup files ( full backup only is fine in this case ) in the Azure storage account as well as the target database name you eShop. Notice that the DMS restore creates the eShop database, in other words the database should not exist already there.

![DMS_10](./images/DMS_10.png)

Start the migration. 

![DMS_11](./images/DMS_11.png)

Follow the migration progress. Notice the migration details.

![DMS_12](./images/DMS_12.png)

If all is well,  the full backups would have been restored.

![DMS_13](./images/DMS_13.png)

<<<<<<< HEAD
The work is not done yet.  Since this is an online migration, transaction logs need to be replayed.  As a test to prove that transactions logs completed successfully and no data loss occured, go to the source database and add a new row to a table. Use SSMS 22 to launch a query window and run the command to insert a row into the *dbo.Store* table.

```powershell
INSERT INTO dbo.Store
           (Name
           ,City
           ,State
           ,Hours)
     VALUES
           ('Test'
           ,'Test'
           ,'Test'
           ,'Test');
GO
```
=======
Database migration is not complete yet.  Since this is an online migration, transaction logs need to be replayed.  The LRS can only be triggered via Azure CLI or PowerShell. The *datamigration* extension needs to be installed on the commandline. 

Launch Azure CLI and then run this command

```shell
az extension add --name datamigration --upgrade
```

Once that is done, as a test to prove that transactions logs completed successfully and no data loss occured, go to the source database and add a new row to a table. Use SSMS 22 to launch a query window and run the command.
>>>>>>> 906f367 (minor fix, simplification till challenge 3 and part of 4)

![DMS_14](./images/DMS_14.png)

Next we need to backup the transaction logs to the storage account, in the same folder/location as the database backups.  Use SSMS to do this as well. Opt for *Transactions Logs* as the back up type.

![DMS_15](./images/DMS_15.png)

You can follow the progress of the log replay from the portal, same place as where the progress of the migration was being followed.

![DMS_122](./images/DMS_12.png)

The transaction logs have all been played when there are no files left to restore.

![DMS_17](./images/DMS_17.png)

Perform the cutover. Wait for it to complete.

![DMS_18](./images/DMS_18.png)

Navigate to the Azure SQL Managed instance and confirm the database is there and in good state. Click on *Databases* in the left to list all databases on this managed instance.

![DMS_19](./images/DMS_19.png)

Go back to SSMS 22.  Connect to the Azure SQL Managed Instance and eShop database using Entra. Explore the tables and make sure they are all there.  Confirm the row you added above is also present. 

#### Congratulations - you have migrated to Azure SQL

## Challenge 5  — Enable private endpoint for SQL Managed Instance

## Student tasks

1. Create a private endpoint for the Azure SQL logical server. Go to Azure portal - -> Security --> Networking --> Private Access
2. Configure the private endpoint in the same region where you want to connect from.
3. One the azure portal, search for your private DNS zone just created for SQL Database. Under DNS Management ---> Virtual Network Links, 
add links to the Vnet where you want to connect to this SQL database from azure. 
4. Ensure net connectibity using private endpoint from your source something like 
```text
test-NetConnection <your-logical-server>.database.windows.net -Port 1434
```

privatelink.database.windows.net <b>"privatelink.database.windows.net"</b> 

1. Link the private DNS zone to the VNet.
2. Associate the private endpoint with a DNS zone group.
3. Confirm that the private endpoint connection is approved.

## Success criteria

* The Azure SQL server name resolves to a private IP from the VM.
* TCP 1433 is reachable from the VM.
* Public network access remains disabled.

## Challenge 6  — Application readiness - Entra-id authentication for app

## Student tasks

1. Read the dedicated Lab 04 runtime identity resource ID:

   ```powershell
   $runtimeIdentityResourceId = gh variable get LAB06_RUNTIME_IDENTITY_RESOURCE_ID
   $runtimeIdentityPrincipalId = az identity show `
     --ids $runtimeIdentityResourceId `
     --query principalId `
     --output tsv
   ```

2. Connect to the Azure SQL `eShop` database as the configured Microsoft Entra administrator.
3. Create a container user for the Container App identity. Use a unique alias and its object ID so the database principal does not depend on Entra display-name uniqueness:

   ```sql
   CREATE USER [caldova_retail_app] FROM EXTERNAL PROVIDER
     WITH OBJECT_ID = '<runtime-identity-principal-id>';

   ALTER ROLE db_datareader ADD MEMBER [caldova_retail_app];
   ALTER ROLE db_datawriter ADD MEMBER [caldova_retail_app];
   ```

4. Do not grant `db_owner` or `db_ddladmin`; the runtime application reads and writes data but does not own schema deployment.
5. Prepare a passwordless application connection string using the Azure SQL FQDN:

   ```text
   Server=tcp:<server>.database.windows.net,1433;Initial Catalog=eShop;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
   ```

6. Confirm TLS encryption and managed-identity authentication.
7. Test representative application operations.
8. Identify features that require redesign after migration.
9. Document rollback criteria and a cutover plan.

## Success criteria

The Container App identity has only the required database roles, the connection string contains no password, and the student demonstrates that application readiness requires more than successful data copy.


Suggested class schedule

|  |  |  |
| --- | --- | --- |
| **Phase** | **Challenges** | **Suggested time** |
| Source preparation | 1–3 | 45–60 minutes |
| Target preparation | 4–7 | 60 minutes |
| DMS configuration | 8–9 | 45 minutes |
| Troubleshooting | 10–11 | 60 minutes |
| Data migration | 12 | 30–60 minutes |
| Validation and closeout | 13–15 | 60 minutes |


### Instructor debrief questions

1. Why must compatibility assessment occur before migration?
2. What roles do Private Link and private DNS play?
3. Why should clients use the Azure SQL FQDN instead of its private IP?
4. What evidence is required before declaring the migration successful?
5. What would change for a production migration with minimal downtime?
6. Which steps should be automated for repeatable delivery?

**Lab principle:** A migration is complete only after compatibility, connectivity, schema, data, application behavior, security, and operational readiness have all been validated with evidence.
