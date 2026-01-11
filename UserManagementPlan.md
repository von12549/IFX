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



