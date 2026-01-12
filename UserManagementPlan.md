# User Management Plan
This will explan how we want to complete the User function design

# User Role
The first part is User Role.
1. Create UserRole Table in Database which will have "RoleName" and "Description" fields.
2. UserRole table will have two rows for now: RoleName: Admin and RoleName: User. Feel free to add something in description field.
3. Add UserRole field in User Table. Each User will contain one and only one Role. The Default value is "User".
4. Update all local users with the default UserRole value.
5. Update all related models/DTOs/viewModels

# User Management Function
The second part is User Management Controller and Functions
1. Create UserManagement Controller in API project.
2. Create Get Endpoint Users which will return all local users. Using UserProfileDto.
3. Only User who has the Role:Admin can access UserManagementController.


# User Management Function Part 2
1. Create Endpoint in UserManagementController to Update User Profile in Local Database (Username, FirstName, LastName, PhoneNumber)
2. Create RoleController in API project.
3. Add a new row in Role table, RoleName:SsoUser.
4. Add Get/Update/Add Endpoint in Role Controller to Get All Roles/Update a specific RoleName and Description/Add a new Role
5. Only User who has the Role:Admin can access RoleController

# Issuer: User Table
1. Add new Fields in User Table "Issuer". The Default value is 'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P'.
2. Update all rows in User Table, set Issuer value to default value.
3. Update Register process to add Issuer into User table.
4. Rename CognitoUserId in User Table to 'Subject'.
5. Update all related models/DTOs/viewModels.

# IdP Table
1. Add new Table IdP (Identity Provider) which will contains: 
    IdpId(PK)
    Name: string, 
    Issuer: string, (Unique) 
    Description: string, 
    LoginUrl: string,
    Enabled: bool (Default: true),
    AutoProvisionEnabled: bool (Default: true),
    Authority: string,
    ExpectedAudiences: json string,
    AllowedAlgs: json string,
    RequiredScopes: json string,
    ClaimMapping: json string,
    ClockSkewSeconds

2. Add a new record in IdP Table:
    Name: 'IFX Cognito',
    Issuer: 'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P',
    Authority: 'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P'

3. Create Idp Controller and create CRUD endpoint
4. Only User who has the Role:Admin can access IdP Controller

# User Re-Design
Aim: Re-design the User Database structure to meets SSO - Multi IdP login requirements
Basicly, Seperate current User table into two different tables:
    User Table: Local User which will be the main table which provide Primary Key, Status, and business fields like DisplayName,
    UserIdentity Table: External User Identity which will contains User Idp info
Reason:
1. User from same IdP would have unique Email and Subject but in different IdPs could be not unique. 
2. Usually User from different IdP should one-to-one mapping to Local User, however we might see some Users have different IdP credentials who want to merge their account.


Main re-design targets:
1. Change the current Module name from "Cognito" to "Auth".
2. Change the database scheme "cognito" to "auth".
3. Rename the current Users Table to UsersBackup.
4. Create new User Table which will contains:
    UserId: (PK, GUID),
    IsActive: bool (Default true),
    UserRoleId: (FK -> Role table),
    DisplayName: string 

5. Create new UserIdentity Table which will contains:
    UserIdentityId: (PK),
    UserId: (FK -> User table),
    Issuer: string,
    Subject: string,
    Unique Contraints (Issuer, Subject),
    IdpId: (FK -> Idp table),
    Email: string (not null),
    EmailVerified: bool,
    FirstName: string,
    LastName: string,
    BirthDate: string (Format: yyyy-MM-dd),
    PhoneNumber: string,
    PhoneNumberVerified: bool,
    LastSyncedAt: datetime

6. Foreach user in UsersBackup table, create records in new User table first and then use the FK to create records in UserIdentity table. DisplayName in User table will be Firstname+LastName as default.
7. Modify current Register Process, logic will be same as step 6
8. Review/Update all user related methods. All requests which using Sub before should first look the Subject&Issuer from UserIdentity table and then use UserId to get the real Local User.






