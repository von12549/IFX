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

