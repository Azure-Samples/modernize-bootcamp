# Lab 05: Database Modernization Bootcamp

> [!NOTE] This lab requires additional Azure resources to be deployed.   
> - Azure Storage account
> - Azure Database Migration Service
> - Blob container
> - Blob folder
> - Azure Database Migration Service (DMS) 
> - DMS SQL Instance
> 
> They must follow a certain naming convention.  All resources you create must end with i.e. have a suffix @lab.LabInstance.Id.  Failing to do so, will block you from creating those Azure resources.
>
> - Storage account: `caldovalab05st@lab.LabInstance.Id`
> - Blob container: `sqlmi-backups-@lab.LabInstance.Id`
> - Blob folder: `eshop-@lab.LabInstance.Id`
> - DMS: `caldova-lab05-sqlmig-@lab.LabInstance.Id`
> - DMS SQL Instance: `caldovalab05sql@lab.LabInstance.Id`


An Azure policy in place enforces a certain naming convention for these resources.

## SQL Server to Azure SQL Database — Student Migration Challenges

**Scenario:** Migrate the eShop database from SQL Server on VM to Azure SQL Database by using Azure Database Migration Service (DMS).

Now that the application is upgraded and moved to Azure PaaS services, it is time to modernize and migrate the database. 

***Security rule:*** *Never expose passwords, storage keys, SAS tokens, or connection strings in screenshots or submissions. Do not enable public RDP or public Azure SQL access unless the instructor explicitly requires it.*

Learning objectives

Students will learn to:

* Gather information about a SQL server database.
* Learn about different authentication mechanisms in SQL server.
* Learn about different types of backups and migration techniques.
* Run an assessment of the source SQL Server database, analyze the report.
* Create Azure Data Migration Service (DMS)
* Run DMS online migration to SQL MI and verify migration. 

## Challenge 1 — Validate the source database

### Student tasks

1. Open SQL Server Management Studio from the task bar. It would have pre-populated login to the source database.
2. Connect to the local SQL Server using "sa" SQL login given to you.
3. Right click on the server and click on "New Query".
4. Execute the following SQL.

```sql
Use master;
select @@version ;
```
5. Right click on database eshop and click on properties to determine database size, collation, disk file name and size of database files and "recovery mode", as shown.

[![this](./images/Challenge_1_db_properties.png)](./images/Challenge_1_db_properties.png)

6. Note the "page" names displayed when checking on database "properties" section. The "page" list will be different for SQL Managed Instance that we will migrate to, later.
7. From the "Files" section, note down the data files and transaction log file name.
8. You connected to the SQL server using SQL authentication. What are other ways to authenticate to a SQL server?
9. (Research on this) What is a logical and physical backup of SQL database ?
10. (Research on this) different type of recovery modes for SQL database.
11. Put the database into full recovery mode in SSMS running this query.

```sql
ALTER DATABASE
 eshop 
SET RECOVERY 
 full ;
```
12. Verify that the eshop database was placed in full recovery mode.

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
* You can explain at least four different authentication mechanisms and show at least two ways to connect.
* You understand that logical backup (.bacpac) is an export of data structure and data that can be moved across OS/versions of SQL. It is also a point-in-time backup. Under the hood, a .bacpac file is simply a compressed ZIP package containing JSON/XML metadata definition files and data
* A physical backup (.bak) by contrast is page-by-page physical copy of files. Along with transaction log backups, a physical backup can be used to restore database with minimal data loss - as you will do in this lab later.
* You can explain recovery model and different types of backups.

## Challenge 2 — Pre-migration assessment of the source database 

SSMS 22 is the latest version of Microsoft’s SQL Server Management Studio, a 64-bit graphical tool for managing, developing, and administering SQL Server and Azure databases. We will use it in the lab to perform the database assessment, querying and performing the necessary backups to upload to Azure storage for the migration. To launch the tool, locate on the labs desktop the shortcut:

 ![SSMS](./images/ssms_22.png)

### Student tasks


1. ### Using SSMS, connect to the SQL Server 2016  that resides on a VM in this lab environment. The connection to "on-premises" SQL server is preconfigured in the lab. Right click on the server and choose "Migrate SQL Server".

 ![SSMS2](./images/Challenge_2_assessment_launch_1.png)


2. #### Do not Migrate or Upgrade the database.

Run a "Migration readiness assessment". An html file will open in your browser once the assessment completes. This is the report.

 ![SSMS](./images/Challenge_2_assessment_launch_2.png)

3. ### Investigate the report. Find out compatibility issues with different SQL targets. 

![Assessment](./images/Challenge_2_assessment_full_report.png)

4. ### Prepare to connect to the target SQL Managed Instance. Before you can connect to it, you need to open up the firewall to allow connection to the SQL MI first.

#### Validate NSG inbound rules for SQL MI's subnet NSG before beginning.

From the portal, find out the NSG for the subnet that Azure SQL Managed Instance is configured with.  The preprovisioned Azure SQL Managed instance is pre-provisioned in the resource group called *rg-caldova-lab04-secondary-@lab.LabInstance.Id*.  The managed instance is called *caldovalab04mi@lab.LabInstance.Id*.  The associated NSG is called *caldova-lab04-sqlmi-@lab.LabInstance.Id-nsg*. 
 
 ![NSG2](./images/NSG2.png)
 
 Click on *caldova-lab04-sqlmi-@lab.LabInstance.Id-nsg*. Navigate to the Inbound rules:

 ![NSG3](./images/NSG3.png)
 
 Add an inbound port rule like this to allow inbound connections on port 3342:

 ![NSG1](./images/NSG1.png)

Now you are able to connect to SQL MI from your SQL Server Management Studio tool.

5. ### The Azure SQL Managed Instance configured in this lab is configured to **authenticate** using **<u>Entra only.</u>**

Notice that there are several ways you can authenticate to SQL server using Entra. In this lab, you must select authentication method <b>Entra with Password.</b>  

The public endpoint is used to connect from the virtual lab environment therefore when connecting using SSMS, port 3342 needs to be used.  

*Note* Your SQL entra login will be the same user as your <b>azure login </b>. 

6. ### Retrieve the public endpoint FQDN and port number (3342) to use as part of the connection information

 Navigate to the Azure SQL Managed Instance in the portal.  Go to *Connection strings* under *settings* and lookup the public endpoint examples. You need to copy only the servername and the port, as shown here.

![AZSQLMIPE](./images/AzSQLMIPE.png)

Use that Entra ID and password to login using SSMS. This is same as your azure login. Be sure to change the Authentication to <b>Microsoft Entra Password</b>


![SSMS_LOGIN](./images/ssms_login.png)


7. ### Connect to the target SQL MI using SSMS. 

<b>Explore SQL MI on Azure portal:</b> 

- Click on SQL Managed Instance and then expand on the left panel --> "Data Management" --> "Databases".

- Notice that there is a database called eshop_ai there. We will not use this in this lab.

- You will restore the on-premises database to a new "eshop" database in this managed instance.


## Success criteria

* You learn how to run an assessment using SSMS 22.
* Understand the assessment report and the compatibility issues.
* You are able to connect to the SQL MI from the lab VM using Entra ID.

## Challenge 3 — Create the required azure resources - Storage account and DMS

In this part of the lab you will create the necessary Azure resources to perform the migration. Deploy the resources in the same region that Azure SQL MI is deployed.  You will:

- Create a resource provider (if it does not exist) in the subscription for DMS.
- Deploy an Azure storage account and a blob container to store database and transaction log file backups.
- Deploy an Azure Database Migration Service (DMS) to migrate the database.


### Student tasks

#### <u>Special Note:</u> 👉👉 Both the DMS and the Storage account needs to be in the same region as the target SQL MI 

#### 1. Storage Account

<b>1a.</b> Provision an Azure Storage Account `caldovalab05st@lab.LabInstance.Id` <b>in the same region as the Azure SQL Managed Instance </b>

Create a Blob container `sqlmi-backups-@lab.LabInstance.Id` in it to store source database backup. 

![Storage1](./images/Storage_1.png)
![Storage3](./images/Storage_3.png)

<b>1b.</b> Once the storage account is created, you will need to allow yourself the permission to manage Blob containers. 

 Do this via IAM.  Assign the *Storage Blob Data Owner* (or Contributor) role to your own Entra ID.

![Storage5](./images/Storage_5.png)
![Storage6](./images/Storage_6.png)
![Storage7](./images/Storage_7.png)
![Storage8](./images/Storage_8.png)

<b>1c.</b> Similarly, you will need to grant permission so that the Managed Identity of the SQL MI can retrieve the backup, i.e. it has role "Storage Blob Data Reader" role assigned.

 The identity has the same name as the SQL MI instance your lab subscription.

![Storage10](./images/Storage_10.png)

<b>1d.</b> Create a Blob container `sqlmi-backups-@lab.LabInstance.Id` in the storage account and a folder `eshop-@lab.LabInstance.Id` within the container. 

Note that the container name and folder name are unique to your lab environment and are not reflected in the images below.  

Use the images as an example of what the outcome should be.

![Storage11](./images/Storage_11.png)
![Storage12](./images/Storage_12_2.png)

#### 2. Ensure Azure SQL MI System Assigned Managed Identity

You will need to validate that *System Assigned Managed Identity* is enabled for the SQL Managed Instance.  

Locate the pre-deployed Azure SQL Managed instance in your lab subscription. 

Go to the *Identity* blade under Security and confirm that *System Assigned Managed Identity* is enabled.  If it is not then enable it.

![SQLMI_SAMI](./images/SQLMI_SAMI.png)

#### 3. Resource provider for DMS

From the Azure portal, go to *Subscriptions*.  Expand on settings. Click on *Resource Providers* and confirm that *Microsoft.DataMigration* is registered.  If it is not, then register it.

![ResourceProvider](./images/dms_resource_provider.png)


#### 4. Database Migration Service (DMS)

<b>In the same region where Azure SQL MI</b> is deployed in the lab subscription, deploy Azure Database Migration Services (DMS) `caldova-lab05-sqlmig-@lab.LabInstance.Id`. 

Search for **"dms" in "Azure Services only".** 

![DMS1_1](./images/DMS_1_1.png)

![DMS1](./images/DMS_1.png)

***Make sure to choose the migration scenario as from SQL server to Azure SQL Managed Instance.*** 

![DMS1_2](./images/DMS_1_2.png)

![DMS1_3](./images/DMS_1_3.png)


## Success criteria

- Resource provider is registered for data migrations.
- SQL MI configured for System Assigned Managed Identity.
- Storage account is created in the same region as MI, with a Blob container in it.
- DMS is deployed in the same region as SQL MI.


## Challenge 4 — Online Migration from on-premises SQL Server to SQL Managed Instance

In this challenge you will perform database backups to the Azure Storage account provisioned earlier.  You will then use DMS to perform an *Online* migration. To perform an online migration, DMS restores the full and any differential backups before restoring and playing transaction logs to complete the migration. 

### Student tasks

#### 1. Backup the database to Azure Storage using SSMS 22

<b>1a.</b> Launch SSMS from the desktop:

 ![SSMS22](./images/ssms_22.png)

<b>1b.</b> Connect to the source database that resides in the VM. Expand the tree and Database folder and locate the *eShop* database. Right click and select Tasks->Backup.

![SSMS22_1](./images/SSMS22_1.png)

<b>1c.</b> Select *Full* for backup type and *URL* for *Back up to*. Click on *Add* to select the Azure Storage account and Blob container.

![SSMS22_2](./images/SSMS22_2.png)

Click on *New Container*.

![SSMS22_3](./images/SSMS22_3.png)

<b>1d.</b> Login to the lab's subscription and select the storage account and container created earlier. Generate SAS credentials and save them in notepad. Click OK.

![SSMS22_4](./images/SSMS22_4.png)

<b>Note:</b>

 Complete the backup, prefix the file with the blob container folder name `eshop-@lab.LabInstance.Id` and "full_" so you can identify the file easily in the azure portal in the storage container. 

![SSMS22_5_2](./images/SSMS22_5_2.png)

<b>1e.</b> Repeat the task this time taking a differential backup - with a name prefix of the blob folder eshop-@lab.LabInstance.Id and "diff_" .

![SSMS22_6](./images/SSMS22_6.png)

<b>1f.</b> The backups should be listed in the Blob container in the storage account.

Notice the size of the full and the differential backups. 


![SSMS22_7_2](./images/SSMS22_7_2.png)

### 2. Migrate the database online using DMS

<b>2a.</b> Navigate to the Azure portal to the DMS service created earlier.  Select "New Migration".

![DMS_6](./images/DMS_6.png)

<b>2b.</b> Next, choose the migration scenario - from Sql Server to Azure SQL MI.
Choose <b>Blob</b> as backup location and <b>online</b> as backup mode.

![DMS_7](./images/DMS_7.png)

<b>2c.</b> On the next page, configure details as shown. 

> [!Note]
> 
> DMS needs to configure a SQL Instance `caldovalab05sql@lab.LabInstance.Id` to track progress of migration for restartability. 
> 
> What you are entering here is information for that tracking database - not  your source or target database. You need not manage this instance for this lab. 

> [!Note]
> 
> - This tracking database can be in a different region also. 
> - Furthermore, if for some reason you want to try the migration again, you would need to provide a new tracking SQL instance.


![DMS_8](./images/DMS_8.png)

<b>2d.</b> Select the Azure SQL managed Instance that already exists as a target.

![DMS_9](./images/DMS_9.png)

<b>2e.</b> Specify the location of the backup files in the Azure storage account as well as the target database name `eShop`. 

![DMS_10](./images/DMS_10.png)

<b>2f.</b> Start the migration. 

![DMS_11](./images/DMS_11.png)

<b>2g.</b> Follow the migration progress. Notice the migration details.

![DMS_12](./images/DMS_12.png)

<b>2e.</b> If all is well,  the full backups would have been restored.

![DMS_13](./images/DMS_13.png)

<b>2f.</b> The migration is not complete yet.  

Since this is an online migration with minimal outage, the migration will move any incremental data that was added since the migration started. In this lab, you will add some data to source and use backup of transaction logs to move that new data across. 


First, you will add some data on the source SQL server

<b>2g.</b> Go to the source database and add a new row to a table. Use SSMS 22 to launch a query window and run the command. 

You can enter a few more rows if you want.

```sql
INSERT INTO
 dbo.store 
VALUES
 ( 'Test', 'Test', 'Test', 'Test' ) ;
```

<b>2h.</b> Next we need to backup the transaction logs to the storage account, in the same folder/location as the database backups.  Use SSMS to do this as well. Opt for *Transactions Logs* as the back up type.

> [!NOTE]
>
> Prefix the file name with the blob folder `eshop-@lab.LabInstance.Id` and "log_" so you can identify the file easily.

![DMS_15_2](./images/DMS_15_2.png)

<b>2i.</b> You can follow the progress of the log replay from the portal, same place as where the progress of the migration was being followed.

> [!NOTE]
>
> - When you take a backup of the source database, DMS may take a minute or two to see the backup.
>
> - Notice the order of restore operation of DMS - first full, then differential, then logs - in the same order that the backup was taken. 

![DMS_17](./images/DMS_17.png)

<b>2j.</b> Wait until all transaction logs have all been restored and no files are left ( as seen in azure storage ) to restore.

***Perform the cutover. Wait for it to complete.***

![DMS_122](./images/DMS_12.png)



![DMS_18](./images/DMS_18.png)

<b>2k.</b> Navigate to the Azure SQL Managed instance and confirm the database is there and in good state. Click on *Databases* in the left to list all databases on this managed instance.

![DMS_19](./images/DMS_19.png)

<b>2l.</b> Go back to SSMS 22.  Connect to the Azure SQL Managed Instance and eShop database using Entra. Explore the tables and make sure they are all there.  Confirm the row you added above is also present. 

Run this following query to confirm the new row(s) you added

```sql
SELECT 
 *
FROM
 dbo.store 
WHERE 
 name like 'Test%' ;
```

<b>Congratulations - you have migrated to Azure SQL</b>

## Challenge 5 - Perform online migration using CLI (Optional)

If you completed challenges 1- 4 in under 2.5 hours, you can proceed with challenge 5.  Otherwise click on *Next* in the set of instructions and move on to the apps portion of day 2.  You can always navigate back to this page and complete challenge 5 if you have time.

### VM SQL Server to Azure SQL Managed Instance with Azure DMS Via CLI 

### Objective

Migrate on-premises SQL Server databases to Azure SQL Managed Instance using Azure CLI and Azure Database Migration Service (DMS). The flow includes assessment, remediation, provisioning, data migration, cutover, and post-migration validation.

#### End-to-End Flow

```text
Compatibility assessment
        |
Remediate blockers and reassess
        |
Prepare storage and backups
        |
Create Azure Database Migration Service
        |
Start online migration
        |
Monitor backup restoration
        |
Cut over applications
        |
Validate
```

For simplicity, the exercise will use the same Database Migration Service (DMS) and the same storage account 
and backups as the previous exercise.

The challenge uses Azure CLI from PowerShell. The <b>az datamigration</b> command group is an Azure CLI extension and requires Azure CLI 2.75.0 or later.

### 1. The Migration Mode

| Mode | Behavior | Downtime |
|---|---|---|
| Online | DMS restores a full backup and continually restores transaction-log backups. An explicit cutover completes the migration. | Usually limited to final cutover |

Use online migration when the source database must remain available while data is copied.

### 2. Prerequisites

Before starting:

1. Locate the Azure SQL Managed Instance already provisioned in your lab environment's subscription.
3. Establish connectivity by using SSMS 22 installed on the lab VM's desktop, use the Entra with Password account.

![SSMS22](./images/ssms_22.png).


### 3. Install and Configure Azure CLI

```powershell
az version
az upgrade

az extension add --name datamigration --upgrade

az login

az provider register --namespace Microsoft.DataMigration

az provider show `
    --namespace Microsoft.DataMigration `
    --query registrationState `
    --output tsv
```

The expected provider registration state is <b>Registered</b>.

### 4. Run the Migration Assessment

The assessment runs locally and does not require a DMS resource.

<b>4a.</b> Using SSMS 22, connect to the *master* database in a query window and create a sysadmin user.
Avoid using special characters in the user and password in these exercises as to not spend time escaping characters
in the commands that need to run from command line.  Use this account to perform the assessment.

```sql
USE [master]
GO
-- Step 1: Create a SQL Server Login
CREATE LOGIN [AdminUser]
WITH PASSWORD = '<put a password of your choosing here>';

-- Step 2: Add the Login to the Sysadmin Role
ALTER SERVER ROLE [sysadmin]
ADD MEMBER [AdminUser];
GO
```

<b>4b.</b> Connectivity to the SQL server will use SQL Server authentication. 

 The *AdminUser* account created above will be used.  

Run the cmdlet below to start an assessment. 

- The command below assumes your source IP address, correct it if needed.
- Put your password that you chose below within the double quote "" below. 

#### SQL Server Authentication

```powershell
$AssessmentFolder = $HOME

$AssessmentConnection = "Data Source=192.168.1.100;Initial Catalog=master;Integrated Security=False;User Id=AdminUser;Password=<put password here>"

az datamigration get-assessment `
    --connection-string $AssessmentConnection `
    --output-folder $AssessmentFolder `
    --overwrite
```

![cli_assess](./images/cli_assessment.png)

<b>4c.</b> Review the resulting HTML or JSON for:

- Server-level assessment issues
- Database-level assessment issues
- TargetReadinesses.AzureSqlManagedInstance
- Warnings and errors
- DatabaseRestoreFails
- Impacted objects
- Recommended remediation

![cli_report](./images/cli_report.png)

<b>4d.</b> Pay particular attention to unsupported features, cross-database dependencies, CLR, linked servers, SQL Agent dependencies, Windows authentication dependencies, file layouts, database sizes, and encryption.

<b>4e.</b> Resolve blocking issues and rerun the assessment. Retain the before-and-after reports as migration evidence.

## 5. Collect Performance Data and Obtain SKU Recommendations (optional)

The extension provides these commands:

```powershell
az datamigration performance-data-collection --help
az datamigration get-sku-recommendation --help
```

Collect performance data during normal operations, peak business hours, batch windows, reporting periods, and maintenance activity.  
There is no load placed on the database for this lab hence nothing meaningful will be produced.

Use the results to select:

- General Purpose or Business Critical
- vCore count
- Storage capacity and performance tier
- Zone redundancy

Include enough headroom for workload growth and operational spikes.


## 6. Perform an Online Migration using Azure CLI
These are the overall steps of an online migration using DMS from Azure CLI.

1. Take a full backup.
2. Take a differential backup.
2. Upload it to the migration Blob container at the *root*.
3. Continue taking transaction-log backups.
4. Upload each log backup in sequence.
5. Do not break the transaction-log chain.
6. During cutover, stop writes and take a final tail-log backup.

#### Backups

Unlike backing up the database files into a folder in an Azure Storage Account BLOB container  when running DMS from the portal, running DMS from the CLI requires that the backup files reside in the root of the container.  Copy the existing backups from the earlier exercise to the root of the BLOB container. Optionally, create new full, differential and transaction log backups and place them at the root of the container.  Either will work.

![cli_backups](./images/cli_backups.png)
 
## 7. Start an Online Migration

Get the environment information.  Fill in all information for the variables according to your environment. Start the migration.

```powershell
$StorageAccount = "caldovalab05st@lab.LabInstance.Id"
$StorageResourceGroup = az storage account list --query "[?name=='$StorageAccount'].resourceGroup | [0]" --output tsv
$MiResourceGroup = "rg-caldova-lab04-secondary-@lab.LabInstance.Id"
$ManagedInstance = "caldovalab04mi@lab.LabInstance.Id" 
$MigrationResourceGroup = az resource list --name "caldova-lab05-sqlmig-@lab.LabInstance.Id" --resource-type "Microsoft.DataMigration/sqlMigrationServices" --query "[0].resourceGroup" --output tsv
$MigrationService = "caldova-lab05-sqlmig-@lab.LabInstance.Id"

$StorageAccountId = az storage account show `
    --resource-group $StorageResourceGroup `
    --name $StorageAccount `
    --query id `
    --output tsv

$ContainerName = az storage container list `
    --account-name  $StorageAccount `
    --auth-mode login `
    --query "[].name" `
    --output tsv

$ManagedInstanceId = az sql mi show `
    --resource-group $MiResourceGroup `
    --name $ManagedInstance `
    --query id `
    --output tsv

$ManagedInstanceLocation = az sql mi show `
    --resource-group $MiResourceGroup `
    --name $ManagedInstance `
    --query location `
    --output tsv

$MigrationServiceId = az datamigration sql-service show `
    --resource-group $MigrationResourceGroup `
    --sql-migration-service-name $MigrationService `
    --query id `
    --output tsv

$StorageAccountKey = az storage account keys list `
    --resource-group $StorageResourceGroup `
    --account-name $StorageAccount `
    --query "[0].value" -o tsv

$SourceLoc = @{
    AzureBlob = @{
        storageAccountResourceId = $StorageAccountId
        accountKey = $StorageAccountKey
        blobContainerName = $ContainerName
    }
} | ConvertTo-Json -Depth 10 -Compress


$SourceLocation = $SourceLoc.Replace('"', '\"')

$SourceDatabase = "eShop"
$TargetDatabase = "eShopCLI"

az datamigration sql-managed-instance create `
    --managed-instance-name $ManagedInstance `
    --resource-group $MiResourceGroup `
    --target-db-name $TargetDatabase `
    --scope $ManagedInstanceId `
    --migration-service $MigrationServiceId `
    --source-database-name $SourceDatabase `
    --source-location $SourceLocation
```
### 8. Monitor the Migration

The same information retrieved from the CLI can also be viewed in the portal.

```powershell
az datamigration sql-managed-instance show `
    --managed-instance-name $ManagedInstance `
    --resource-group $MigrationResourceGroup `
    --target-db-name $TargetDatabase `
    --expand MigrationStatusDetails
```
### 9. Cutover

During the controlled change window, these are the typical steps:

1. Stop application writes.
2. Disable jobs and integrations that write to the source.
3. Drain application connections.
4. Take a tail-log backup.
5. Upload the tail-log backup.
6. Wait for DMS to restore it.
7. Record final validation values.
8. Initiate cutover.

Once all 3 backups have been restored, perform the cutover.

Get the migration operation ID:

```powershell
$MigrationOperationId = az datamigration sql-managed-instance show `
    --managed-instance-name $ManagedInstance `
    --resource-group  $MiResourceGroup `
    --target-db-name $TargetDatabase `
    --expand MigrationStatusDetails `
    --query "properties.migrationOperationId" `
    --output tsv
```

Perform the cutover:

```powershell
az datamigration sql-managed-instance cutover `
    --managed-instance-name $ManagedInstance `
    --resource-group  $MiResourceGroup `
    --target-db-name $TargetDatabase `
    --migration-operation-id $MigrationOperationId
```


### 10. Post-Migration Validation

Use SSMS 22 to connect to the eShopCLI database.  Explore the migrated objects.
