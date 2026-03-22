# Test Cases

## Overview

This document is a structured reference of all test cases in the IFX test suite, organized by layer and module. Each entry maps to an actual test method in the codebase.

**Total: 474 tests — 419 backend + 55 frontend**

---

## 1. Domain Tests — 103 tests

### 1.1 User Entity (`UserTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-U-01 | `Create_WithValidParameters_ReturnsUser` | Valid display name | User created; `Id` non-empty; `IsActive = false` |
| D-U-02 | `Create_WithIsActiveTrue_SetsIsActive` | `isActive: true` passed | `IsActive = true` |
| D-U-03 | `Activate_SetsIsActiveTrue` | Inactive user `.Activate()` | `IsActive = true` |
| D-U-04 | `Deactivate_SetsIsActiveFalse` | Active user `.Deactivate()` | `IsActive = false` |
| D-U-05 | `UpdateDisplayName_UpdatesDisplayName` | New name passed | `DisplayName` updated |
| D-U-06 | `Builder_CreatesUserWithCorrectDefaults` | Default builder | `IsActive = false`; default display name set |
| D-U-07 | `Builder_Active_CreatesActiveUser` | `.Active()` builder | `IsActive = true` |

### 1.2 UserIdentity Entity (`UserIdentityTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-UI-01 | `Create_WithValidParameters_ReturnsUserIdentity` | All required fields | Identity created with correct field values |
| D-UI-02 | `Create_StoresSubjectAndEmail` | Subject and email provided | `Subject.Value` and `Email.Value` accessible |
| D-UI-03 | `Create_EmailNotVerified_SetsEmailVerifiedFalse` | `emailVerified: false` | `EmailVerified = false` |
| D-UI-04 | `Create_EmailVerified_SetsEmailVerifiedTrue` | `emailVerified: true` | `EmailVerified = true` |

### 1.3 LoginEvent Entity (`LoginEventTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-LE-01 | `Create_WithValidParameters_ReturnsLoginEvent` | Valid inputs | Event created with timestamp |
| D-LE-02 | `Create_WithDeviceInfo_ParsesDeviceInfo` | User-agent string | `DeviceInfo` populated |
| D-LE-03 | `Create_Success_SetsSuccessTrue` | Successful login | `Success = true` |
| D-LE-04 | `Create_Failure_SetsSuccessFalse` | Failed login with reason | `Success = false`; `FailureReason` set |

### 1.4 EmailVerificationToken Entity (`EmailVerificationTokenTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-EVT-01 | `Create_WithValidParameters_ReturnsToken` | Valid user ID | Token created; code non-empty |
| D-EVT-02 | `Create_SetsExpiryInFuture` | Default creation | `ExpiresAt` > `UtcNow` |
| D-EVT-03 | `IsExpired_WhenNotExpired_ReturnsFalse` | Token within expiry | `IsExpired = false` |
| D-EVT-04 | `IsExpired_WhenExpired_ReturnsTrue` | Expired token | `IsExpired = true` |

### 1.5 Role Entity (`RoleTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-R-01 | `Create_WithValidParameters_ReturnsRole` | Valid name + description | Role created; `Id` non-empty |
| D-R-02 | `AddPermission_AddsToCollection` | Permission added | Permissions collection contains permission |
| D-R-03 | `RemovePermission_RemovesFromCollection` | Permission removed | Permissions collection no longer contains permission |

### 1.6 EmailAddress Value Object (`EmailAddressTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-EA-01 | `Create_WithValidEmail_ReturnsEmailAddress` | Valid email | `Value` normalized to lowercase |
| D-EA-02 | `Create_WithUpperCase_NormalizesToLower` | `"User@Domain.COM"` | `Value = "user@domain.com"` |
| D-EA-03 | `Create_WithNull_ThrowsOrReturnsEmpty` | Null input | Exception or empty value |
| D-EA-04 | `Create_WithEmptyString_ThrowsOrReturnsEmpty` | Empty string | Exception or empty value |
| D-EA-05 | `Equals_SameValue_ReturnsTrue` | Two identical emails | Equal |
| D-EA-06 | `Equals_DifferentValue_ReturnsFalse` | Two different emails | Not equal |

### 1.7 Subject Value Object (`SubjectTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-S-01 | `Create_WithValidValue_ReturnsSubject` | Non-empty string | `Value` stored as-is |
| D-S-02 | `Equals_SameValue_ReturnsTrue` | Two identical subjects | Equal |
| D-S-03 | `Equals_DifferentValue_ReturnsFalse` | Two different subjects | Not equal |

### 1.8 DeviceInfo Value Object (`DeviceInfoTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| D-DI-01 | `Parse_ChromeOnWindows_DetectsCorrectly` | Chrome/Windows user-agent | Browser = Chrome; OS = Windows; IsBot = false |
| D-DI-02 | `Parse_Googlebot_DetectsAsBot` | Googlebot user-agent | `IsBot = true` |
| D-DI-03 | `Parse_Mobile_DetectsMobileDeviceType` | Mobile user-agent | DeviceType = Mobile |
| D-DI-04 | `Parse_EmptyUserAgent_HandlesGracefully` | Empty string | No exception; fields defaulted |

---

## 2. Application Tests — 190 tests

### 2.1 Authorization Command Handlers

#### CreateRoleCommandHandler (`CreateRoleCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-CR-01 | `Handle_WithNewName_CreatesRoleAndReturnsDto` | Name does not exist | `IsSuccess = true`; role added; SaveChanges called once |
| A-CR-02 | `Handle_WhenNameAlreadyExists_ReturnsFailure` | Name exists in repository | `IsSuccess = false`; error contains "already exists"; no AddAsync |

#### UpdateRoleCommandHandler (`UpdateRoleCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-UR-01 | `Handle_WithValidUpdate_ReturnsSuccess` | Role exists; new name available | `IsSuccess = true`; name updated |
| A-UR-02 | `Handle_WhenRoleNotFound_ReturnsFailure` | Role ID not found | `IsSuccess = false` |
| A-UR-03 | `Handle_WhenNameTaken_ReturnsFailure` | New name exists on different role | `IsSuccess = false`; name conflict error |
| A-UR-04 | `Handle_WithSameName_DoesNotTreatAsDuplicate` | Updating role to same name | `IsSuccess = true` (name check excludes current role) |

#### DeleteRoleCommandHandler (`DeleteRoleCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-DR-01 | `Handle_WithExistingRole_DeletesAndReturnsSuccess` | Role exists | `IsSuccess = true`; SaveChanges called |
| A-DR-02 | `Handle_WhenRoleNotFound_ReturnsFailure` | Role ID not found | `IsSuccess = false` |

#### GetAllRolesQueryHandler (`GetAllRolesQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GAR-01 | `Handle_ReturnsMappedRoleDtos` | Two roles in repository | Returns list of two `RoleDto` objects |
| A-GAR-02 | `Handle_WithEmptyRepository_ReturnsEmptyList` | No roles | Returns empty list |

#### GetRoleByIdQueryHandler (`GetRoleByIdQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GRBI-01 | `Handle_WithExistingRole_ReturnsMappedDto` | Role found by ID | `IsSuccess = true`; DTO returned |
| A-GRBI-02 | `Handle_WhenRoleNotFound_ReturnsFailure` | ID not found | `IsSuccess = false` |

#### AssignPermissionsToRoleCommandHandler (`AssignPermissionsToRoleCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-APR-01 | `Handle_WithValidAssignment_ReturnsSuccess` | Role and all permissions found | `IsSuccess = true`; permissions added |
| A-APR-02 | `Handle_WhenRoleNotFound_ReturnsFailure` | Role ID not found | `IsSuccess = false` |
| A-APR-03 | `Handle_WhenSomePermissionsMissing_ReturnsFailure` | One permission ID invalid | `IsSuccess = false`; error indicates missing permissions |

#### RemovePermissionFromRoleCommandHandler (`RemovePermissionFromRoleCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-RPFR-01 | `Handle_WithAssignedPermission_ReturnsSuccess` | Permission is on role | `IsSuccess = true`; permission removed |
| A-RPFR-02 | `Handle_WhenRoleNotFound_ReturnsFailure` | Role not found | `IsSuccess = false` |
| A-RPFR-03 | `Handle_WhenPermissionNotOnRole_ReturnsFailure` | Permission not assigned | `IsSuccess = false` |

#### CreatePermissionCommandHandler (`CreatePermissionCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-CP-01 | `Handle_WithNewName_CreatesPermission` | Name not taken | `IsSuccess = true`; AddAsync and SaveChanges called |
| A-CP-02 | `Handle_WhenNameAlreadyExists_ReturnsFailure` | Name taken | `IsSuccess = false`; no AddAsync |

#### DeletePermissionCommandHandler (`DeletePermissionCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-DP-01 | `Handle_WithExistingPermission_ReturnsSuccess` | Permission exists | `IsSuccess = true` |
| A-DP-02 | `Handle_WhenPermissionNotFound_ReturnsFailure` | Not found | `IsSuccess = false` |

#### GetAllPermissionsQueryHandler (`GetAllPermissionsQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GAP-01 | `Handle_ReturnsMappedPermissionDtos` | Permissions in repository | Returns mapped list |
| A-GAP-02 | `Handle_WithEmptyRepository_ReturnsEmptyList` | No permissions | Empty list |

#### CreateRoleGroupCommandHandler (`CreateRoleGroupCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-CRG-01 | `Handle_WithNewName_CreatesRoleGroup` | Name not taken | `IsSuccess = true` |
| A-CRG-02 | `Handle_WhenNameAlreadyExists_ReturnsFailure` | Name taken | `IsSuccess = false` |

#### DeleteRoleGroupCommandHandler (`DeleteRoleGroupCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-DRG-01 | `Handle_WithExistingRoleGroup_ReturnsSuccess` | Group exists | `IsSuccess = true` |
| A-DRG-02 | `Handle_WhenRoleGroupNotFound_ReturnsFailure` | Not found | `IsSuccess = false` |

#### AssignRolesToRoleGroupCommandHandler (`AssignRolesToRoleGroupCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-ARRG-01 | `Handle_WithValidAssignment_ReturnsSuccess` | Group and all roles found | `IsSuccess = true`; roles assigned |
| A-ARRG-02 | `Handle_WhenRoleGroupNotFound_ReturnsFailure` | Group not found | `IsSuccess = false` |
| A-ARRG-03 | `Handle_WhenSomeRolesMissing_ReturnsFailure` | Partial role resolution | `IsSuccess = false` |

#### GetAllRoleGroupsQueryHandler (`GetAllRoleGroupsQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GARG-01 | `Handle_ReturnsMappedRoleGroupDtos` | Groups in repository | Returns mapped list |
| A-GARG-02 | `Handle_WithEmptyRepository_ReturnsEmptyList` | No groups | Empty list |

---

### 2.2 User Command/Query Handlers

#### GetUserProfileQueryHandler (`GetUserProfileQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GUP-01 | `Handle_WithExistingUser_ReturnsProfileDto` | User found | `IsSuccess = true`; profile fields mapped |
| A-GUP-02 | `Handle_WhenUserNotFound_ReturnsFailure` | ID not found | `IsSuccess = false` |

#### GetUserByIdQueryHandler (`GetUserByIdQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GUBI-01 | `Handle_WithExistingUser_ReturnsUserDto` | User found | `IsSuccess = true` |
| A-GUBI-02 | `Handle_WhenUserNotFound_ReturnsFailure` | Not found | `IsSuccess = false` |

#### GetAllUsersQueryHandler (`GetAllUsersQueryHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-GAU-01 | `Handle_ReturnsPaginatedResult` | Users in repository | Returns `(Users, TotalCount)` |
| A-GAU-02 | `Handle_WithEmptyRepository_ReturnsEmptyResult` | No users | Empty list; count = 0 |

#### AssignRolesToUserCommandHandler (`AssignRolesToUserCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-ARU-01 | `Handle_WithValidAssignment_ReturnsSuccess` | User and roles found | `IsSuccess = true`; roles added |
| A-ARU-02 | `Handle_WhenUserNotFound_ReturnsFailure` | User ID not found | `IsSuccess = false` |
| A-ARU-03 | `Handle_WhenRoleNotFound_ReturnsFailure` | Role ID invalid | `IsSuccess = false` |

#### RemoveRoleFromUserCommandHandler (`RemoveRoleFromUserCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-RRFU-01 | `Handle_WithAssignedRole_RemovesAndReturnsSuccess` | Role assigned to user | `IsSuccess = true` |
| A-RRFU-02 | `Handle_WhenUserNotFound_ReturnsFailure` | User not found | `IsSuccess = false` |

#### AssignRoleGroupsToUserCommandHandler (`AssignRoleGroupsToUserCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-ARGU-01 | `Handle_WithValidAssignment_ReturnsSuccess` | User and groups found | `IsSuccess = true` |
| A-ARGU-02 | `Handle_WhenUserNotFound_ReturnsFailure` | User not found | `IsSuccess = false` |
| A-ARGU-03 | `Handle_WhenRoleGroupNotFound_ReturnsFailure` | Group not found | `IsSuccess = false` |

#### RemoveRoleGroupFromUserCommandHandler (`RemoveRoleGroupFromUserCommandHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-RRGFU-01 | `Handle_WithAssignedGroup_RemovesAndReturnsSuccess` | Group assigned | `IsSuccess = true` |
| A-RRGFU-02 | `Handle_WhenUserNotFound_ReturnsFailure` | User not found | `IsSuccess = false` |

---

### 2.3 Validators

#### RegisterUserCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-01 | `Validate_WithValidCommand_Succeeds` | All fields valid | No validation errors |
| A-V-02 | `Validate_WithEmptyEmail_Fails` | Empty email | Error on Email |
| A-V-03 | `Validate_WithInvalidEmail_Fails` | Malformed email | Error on Email |
| A-V-04 | `Validate_WithShortPassword_Fails` | Password < min length | Error on Password |

#### CreateRoleCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-CR-01 | `Validate_WithValidCommand_Succeeds` | Valid name + description | No errors |
| A-V-CR-02 | `Validate_WithEmptyName_Fails` | Empty/null name | Error on Name |
| A-V-CR-03 | `Validate_WithNameTooLong_Fails` | Name > 50 chars | Error on Name |
| A-V-CR-04 | `Validate_WithNameAtMaxLength_Succeeds` | Name = 50 chars | No error on Name |
| A-V-CR-05 | `Validate_WithEmptyDescription_Fails` | Empty description | Error on Description |
| A-V-CR-06 | `Validate_WithDescriptionTooLong_Fails` | Description > 255 chars | Error on Description |

#### UpdateRoleCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-UR-01 | `Validate_WithValidCommand_Succeeds` | All fields valid | No errors |
| A-V-UR-02 | `Validate_WithEmptyRoleId_Fails` | `RoleId = Guid.Empty` | Error on RoleId |
| A-V-UR-03 | `Validate_WithEmptyName_Fails` | Empty/null name | Error on Name |
| A-V-UR-04 | `Validate_WithNameTooShort_Fails` | Name < 3 chars | Error on Name |
| A-V-UR-05 | `Validate_WithNameTooLong_Fails` | Name > 50 chars | Error on Name |
| A-V-UR-06 | `Validate_WithNameAtMaxLength_Succeeds` | Name = 50 chars | No error on Name |
| A-V-UR-07 | `Validate_WithEmptyDescription_Fails` | Empty description | Error on Description |
| A-V-UR-08 | `Validate_WithDescriptionTooLong_Fails` | Description > 255 chars | Error on Description |

#### CreatePermissionCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-CP-01 | `Validate_WithValidCommand_Succeeds` | Valid inputs | No errors |
| A-V-CP-02 | `Validate_WithEmptyName_Fails` | Empty/null name | Error on Name |
| A-V-CP-03 | `Validate_WithNameTooLong_Fails` | Name > 100 chars | Error on Name |
| A-V-CP-04 | `Validate_WithNameAtMaxLength_Succeeds` | Name = 100 chars | No error on Name |
| A-V-CP-05 | `Validate_WithEmptyDescription_Fails` | Empty description | Error on Description |
| A-V-CP-06 | `Validate_WithDescriptionTooLong_Fails` | Description > 255 chars | Error on Description |

#### UpdatePermissionCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-UP-01 | `Validate_WithValidCommand_Succeeds` | All valid | No errors |
| A-V-UP-02 | `Validate_WithEmptyPermissionId_Fails` | `PermissionId = Guid.Empty` | Error on PermissionId |
| A-V-UP-03 | `Validate_WithEmptyName_Fails` | Empty/null name | Error on Name |
| A-V-UP-04 | `Validate_WithNameTooLong_Fails` | Name > 100 chars | Error on Name |
| A-V-UP-05 | `Validate_WithNameAtMaxLength_Succeeds` | Name = 100 chars | No error on Name |
| A-V-UP-06 | `Validate_WithEmptyDescription_Fails` | Empty description | Error on Description |
| A-V-UP-07 | `Validate_WithDescriptionTooLong_Fails` | Description > 255 chars | Error on Description |

#### CreateRoleGroupCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-CRG-01 | `Validate_WithValidCommand_Succeeds` | Valid inputs | No errors |
| A-V-CRG-02 | `Validate_WithEmptyName_Fails` | Empty/null name | Error on Name |
| A-V-CRG-03 | `Validate_WithNameTooLong_Fails` | Name > 100 chars | Error on Name |
| A-V-CRG-04 | `Validate_WithNameAtMaxLength_Succeeds` | Name = 100 chars | No error on Name |
| A-V-CRG-05 | `Validate_WithEmptyDescription_Fails` | Empty description | Error on Description |
| A-V-CRG-06 | `Validate_WithDescriptionTooLong_Fails` | Description > 255 chars | Error on Description |

#### UpdateRoleGroupCommandValidator

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-V-URG-01 | `Validate_WithValidCommand_Succeeds` | All valid | No errors |
| A-V-URG-02 | `Validate_WithEmptyRoleGroupId_Fails` | `RoleGroupId = Guid.Empty` | Error on RoleGroupId |
| A-V-URG-03 | `Validate_WithEmptyName_Fails` | Empty/null name | Error on Name |
| A-V-URG-04 | `Validate_WithNameTooLong_Fails` | Name > 100 chars | Error on Name |
| A-V-URG-05 | `Validate_WithNameAtMaxLength_Succeeds` | Name = 100 chars | No error on Name |
| A-V-URG-06 | `Validate_WithEmptyDescription_Fails` | Empty description | Error on Description |
| A-V-URG-07 | `Validate_WithDescriptionTooLong_Fails` | Description > 255 chars | Error on Description |

---

### 2.4 Behaviors and Common

#### ValidationBehavior (`ValidationBehaviorTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-VB-01 | `Handle_WithNoValidators_CallsNext` | No validators registered | Next delegate called |
| A-VB-02 | `Handle_WithValidRequest_CallsNext` | Validators pass | Next delegate called; response returned |
| A-VB-03 | `Handle_WithInvalidRequest_ReturnsFailure` | Validator fails | Failure result returned; next NOT called |
| A-VB-04 | `Handle_WithMultipleErrors_AggregatesErrors` | Multiple validator failures | All errors included in result |

#### Result (`ResultTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| A-RES-01 | `Success_SetsIsSuccessTrue` | `Result.Success(value)` | `IsSuccess = true`; `Value` accessible |
| A-RES-02 | `Failure_SetsIsSuccessFalse` | `Result.Failure("error")` | `IsSuccess = false`; `Error` accessible |
| A-RES-03 | `Success_ErrorIsNull` | Successful result | `Error = null` |
| A-RES-04 | `Failure_ValueIsDefault` | Failed result | `Value = default` |

---

## 3. Infrastructure Tests — 45 tests

### 3.1 RoleRepository (`RoleRepositoryTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| I-RR-01 | `GetByIdAsync_WithExistingRole_ReturnsRole` | Role seeded | Role returned; name matches |
| I-RR-02 | `GetByIdAsync_WithNonExistingRole_ReturnsNull` | No matching ID | Returns null |
| I-RR-03 | `GetByNameAsync_WithExistingRole_ReturnsRole` | Role seeded by name | Role returned |
| I-RR-04 | `GetByNameAsync_WithNonExistingRole_ReturnsNull` | Name not found | Returns null |
| I-RR-05 | `NameExistsAsync_WithExistingRole_ReturnsTrue` | Role with name seeded | `true` |
| I-RR-06 | `NameExistsAsync_WithNonExistingRole_ReturnsFalse` | Name not seeded | `false` |
| I-RR-07 | `NameExistsAsync_WithExcludeId_ExcludesSpecifiedRole` | Same name but excluded ID | `false` (self-edit allowed) |
| I-RR-08 | `GetAllAsync_ReturnsAllRoles` | Two roles seeded | List count = 2; both names present |
| I-RR-09 | `AddAsync_AddsRoleToContext` | New role added + SaveChanges | Role persisted; description correct |

### 3.2 PermissionRepository (`PermissionRepositoryTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| I-PR-01 | `GetByIdAsync_WithExistingPermission_ReturnsPermission` | Permission seeded | Permission returned |
| I-PR-02 | `GetByIdAsync_WithNonExistingPermission_ReturnsNull` | Not found | Null |
| I-PR-03 | `GetAllAsync_ReturnsAllPermissions` | Multiple seeded | All returned |
| I-PR-04 | `GetByIdsAsync_ReturnsMatchingPermissions` | Subset of IDs | Only matching returned |
| I-PR-05 | `NameExistsAsync_WithExistingName_ReturnsTrue` | Name present | `true` |
| I-PR-06 | `NameExistsAsync_WithNonExistingName_ReturnsFalse` | Name absent | `false` |
| I-PR-07 | `AddAsync_AddsPermission` | New permission added | Persisted correctly |
| I-PR-08 | `UpdateAsync_UpdatesPermission` | Name/description changed | Updated values persisted |
| I-PR-09 | `DeleteAsync_RemovesPermission` | Permission deleted | No longer in context |

### 3.3 RoleGroupRepository (`RoleGroupRepositoryTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| I-RGR-01 | `GetByIdAsync_WithExistingRoleGroup_ReturnsRoleGroup` | Group seeded | Group returned |
| I-RGR-02 | `GetByIdAsync_WithNonExistingRoleGroup_ReturnsNull` | Not found | Null |
| I-RGR-03 | `GetAllAsync_ReturnsAllRoleGroups` | Multiple seeded | All returned |
| I-RGR-04 | `NameExistsAsync_WithExistingName_ReturnsTrue` | Name present | `true` |
| I-RGR-05 | `NameExistsAsync_WithNonExistingName_ReturnsFalse` | Name absent | `false` |
| I-RGR-06 | `AddAsync_AddsRoleGroup` | New group added | Persisted |
| I-RGR-07 | `UpdateAsync_UpdatesRoleGroup` | Fields changed | Updated values persisted |
| I-RGR-08 | `DeleteAsync_RemovesRoleGroup` | Group deleted | No longer in context |
| I-RGR-09 | `GetByIdWithRolesAsync_EagerLoadsRoles` | Group with roles | Roles navigation populated |

### 3.4 EmailVerificationService (`EmailVerificationServiceTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| I-EVS-01 | `GenerateToken_ReturnsNonEmptyCode` | Fresh call | Non-empty token code |
| I-EVS-02 | `GenerateToken_ExpiryInFuture` | Default TTL | `ExpiresAt > UtcNow` |
| I-EVS-03 | `VerifyToken_WithValidToken_ReturnsTrue` | Valid unexpired token | Verification succeeds |
| I-EVS-04 | `VerifyToken_WithExpiredToken_ReturnsFalse` | Expired token | Verification fails |

---

## 4. Presentation Tests — 10 tests

### 4.1 ClaimsPrincipalExtensions (`ClaimsPrincipalExtensionsTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| P-CPE-01 | `GetUserId_WithUserIdClaim_ReturnsGuid` | `user_id` claim present | Correct Guid returned |
| P-CPE-02 | `GetUserId_WithoutUserIdClaim_ReturnsEmpty` | No `user_id` claim | `Guid.Empty` |
| P-CPE-03 | `GetPermissions_WithPermissionClaims_ReturnsAll` | Multiple `permission` claims | All returned in list |
| P-CPE-04 | `GetPermissions_WithNoPermissions_ReturnsEmpty` | No permission claims | Empty list |
| P-CPE-05 | `HasPermission_WithMatchingClaim_ReturnsTrue` | `permission` claim matches | `true` |
| P-CPE-06 | `HasPermission_WithNoMatchingClaim_ReturnsFalse` | No matching claim | `false` |

### 4.2 HttpContextExtensions (`HttpContextExtensionsTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| P-HCE-01 | `GetIdpConfiguration_WithItemSet_ReturnsConfig` | `IdpConfiguration` in Items | Config returned |
| P-HCE-02 | `GetIdpConfiguration_WithoutItem_ReturnsNull` | Items empty | Null |
| P-HCE-03 | `GetAccessToken_WithTokenSet_ReturnsToken` | `AccessToken` in Items | Token string returned |
| P-HCE-04 | `GetAccessToken_WithoutToken_ReturnsEmpty` | Items empty | Empty string |

---

## 5. Integration Tests — 43 tests

### 5.1 Permission Enforcement Matrix (`PermissionEnforcementTests.cs`)

Each endpoint is tested against three client states: no token → 401, valid token without permission → 403, valid token with correct permission → 200/404.

| ID | Endpoint | Permission Required | No Token | No Permission | Correct Permission |
|----|----------|-------------------|----------|---------------|--------------------|
| IT-PE-01..03 | `GET /api/v1/usermanagement/users` | `User.Read` | 401 | 403 | 200/404 |
| IT-PE-04 | `GET /api/v1/usermanagement/users` | wrong permission `Role.Read` | — | 403 | — |
| IT-PE-05..07 | `GET /api/v1/role` | `Role.Read` | 401 | 403 | 200/404 |
| IT-PE-08 | `GET /api/v1/role` | wrong permission `User.Read` | — | 403 | — |
| IT-PE-09..11 | `GET /api/v1/rolegroup` | `RoleGroup.Read` | 401 | 403 | 200/404 |
| IT-PE-12..14 | `GET /api/v1/permission` | `Permission.Read` | 401 | 403 | 200/404 |
| IT-PE-15..17 | `GET /api/v1/idp` | `Idp.Read` | 401 | 403 | 200/404 |

### 5.2 PermissionAuthorizationHandler (`PermissionAuthorizationHandlerTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| IT-PAH-01 | `HandleAsync_WithMatchingPermission_Succeeds` | Claim matches requirement | Context succeeds |
| IT-PAH-02 | `HandleAsync_WithNoPermissions_Fails` | No permission claims | Context not succeeded |
| IT-PAH-03 | `HandleAsync_WithWrongPermission_Fails` | Wrong permission claim | Context not succeeded |
| IT-PAH-04 | `HandleAsync_WithMultiplePermissions_MatchesAny` | One of many claims matches | Context succeeds |
| IT-PAH-05 | `HandleAsync_WithNoRequirements_DoesNotSucceed` | Empty requirements | No-op |

### 5.3 PermissionAuthorizationPolicyProvider (`PermissionAuthorizationPolicyProviderTests.cs`)

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| IT-PAPP-01 | `GetPolicyAsync_WithPermissionName_ReturnsPolicyWithRequirement` | `"User.Read"` policy name | Policy contains `PermissionRequirement("User.Read")` |
| IT-PAPP-02 | `GetPolicyAsync_WithSameName_ReturnsCachedPolicy` | Called twice with same name | Same policy instance (cached) |
| IT-PAPP-03 | `GetPolicyAsync_WithDefaultPolicyName_ReturnsFallback` | Default ASP.NET policy name | Falls back to default policy provider |
| IT-PAPP-04 | `GetDefaultPolicyAsync_ReturnsAuthenticatedPolicy` | Default policy | Requires authenticated user |

### 5.4 Health Endpoints (`HealthEndpointTests.cs`)

| ID | Endpoint | Expected |
|----|----------|---------|
| IT-H-01 | `GET /health` | 200 OK |
| IT-H-02 | `GET /health/ready` | 200 OK |

---

## 6. Platform Tests

### 6.1 HangfireBackgroundJobService (`HangfireBackgroundJobServiceTests.cs`) — 11 tests

| ID | Method | Scenario | Expected Result |
|----|--------|----------|----------------|
| PL-BJ-01 | `Enqueue<T>` | Valid lambda | `IBackgroundJobClient.Enqueue` called once |
| PL-BJ-02 | `Schedule<T>` | 1 hour delay | `IBackgroundJobClient.Schedule` called with correct delay |
| PL-BJ-03 | `AddOrUpdateRecurring<T>` | Cron expression | `IRecurringJobManager.AddOrUpdate` called with ID and cron |
| PL-BJ-04 | `RemoveRecurring` | Job ID | `IRecurringJobManager.RemoveIfExists` called with ID |

### 6.2 SendGridEmailService (`SendGridEmailServiceTests.cs`) — 12 tests

| ID | Method | Scenario | Expected Result |
|----|--------|----------|----------------|
| PL-SG-01 | `SendEmailAsync` | Basic message | SendGrid client called with To/Subject/HtmlBody |
| PL-SG-02 | `SendEmailAsync` | Default from address | Uses `DefaultFromEmail` from config |
| PL-SG-03 | `SendEmailAsync` | Custom from address | Uses provided from address |
| PL-SG-04 | `SendTemplatedEmailAsync` | Template ID + data | Template ID and dynamic data forwarded |
| PL-SG-05 | `SendTemplatedEmailAsync` | With CC/BCC | CC and BCC recipients included |
| PL-SG-06 | `SendBatchAsync` | Multiple recipients | All recipients dispatched |

### 6.3 NoOpEmailService (`NoOpEmailServiceTests.cs`) — 5 tests

| ID | Method | Scenario | Expected Result |
|----|--------|----------|----------------|
| PL-NOP-01 | `SendEmailAsync` | Any message | Completes without exception; no dispatch |
| PL-NOP-02 | `SendTemplatedEmailAsync` | Any message | Completes without exception |
| PL-NOP-03 | `SendBatchAsync` | Any messages | Completes without exception |

---

## 7. Frontend Tests — 55 tests

### 7.1 Chip Component (`Chip.test.tsx`) — 4 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-CH-01 | Renders label text | `label="Active"` | Text "Active" visible |
| F-CH-02 | Applies active class | `isActive=true` | Element has `chip-active` class |
| F-CH-03 | Calls onClick when active | Active chip clicked | `onClick` callback invoked |
| F-CH-04 | Does not call onClick when inactive | Inactive chip clicked | `onClick` not invoked |

### 7.2 Modal Component (`Modal.test.tsx`) — 5 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-MO-01 | Renders when open | `isOpen=true` | Content visible in DOM |
| F-MO-02 | Hidden when closed | `isOpen=false` | Content absent from DOM |
| F-MO-03 | Closes on Escape key | Escape pressed | `onClose` called |
| F-MO-04 | Closes on × button | × button clicked | `onClose` called |
| F-MO-05 | Renders children | Child content provided | Children rendered inside modal |

### 7.3 SortableHeader Component (`SortableHeader.test.tsx`) — 7 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-SH-01 | Renders column label | `label="Name"` | "Name" text visible |
| F-SH-02 | No active indicator by default | Different column active | No `.sort-active` class on icon span |
| F-SH-03 | Shows active indicator when current | Same column active, `asc` | `.sort-active` class on icon span |
| F-SH-04 | Shows active indicator for desc | Same column active, `desc` | `.sort-active` class on icon span |
| F-SH-05 | Calls onSort on click | Header clicked | `onSort` called with column key |
| F-SH-06 | Click toggles to desc | `asc` active, clicked | `onSort` called with `desc` |
| F-SH-07 | Click toggles to asc | `desc` active, clicked | `onSort` called with `asc` |

### 7.4 ProtectedRoute Component (`ProtectedRoute.test.tsx`) — 3 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-PR-01 | Renders children when authenticated | `user` present in context | Protected content rendered |
| F-PR-02 | Redirects when unauthenticated | `user = null`, not loading | Redirected to `/login` |
| F-PR-03 | Shows loading when auth pending | `isLoading = true` | Loading indicator shown |

### 7.5 API Client / tokenStorage (`client.test.ts`) — 5 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-TC-01 | Saves and retrieves tokens | Save then get | Same token returned |
| F-TC-02 | Returns null when no token | Empty storage | `null` returned |
| F-TC-03 | Clear removes all tokens | Save then clear then get | `null` returned |
| F-TC-04 | Returns null for expired token | Token with past expiry | `null` returned |
| F-TC-05 | Returns token when not expired | Token with future expiry | Token returned |

### 7.6 AuthContext (`AuthContext.test.tsx`) — 5 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-AC-01 | Restores session on mount | Valid token in storage | `user` populated on mount |
| F-AC-02 | `login()` stores tokens and fetches profile | Successful refresh + profile | `user` set from profile response |
| F-AC-03 | `logout()` clears state | Logout called | `user = null`; token storage cleared |
| F-AC-04 | Unauthenticated state | No stored token | `user = null` |
| F-AC-05 | Profile fetch failure | Profile endpoint returns 500 | `user` remains null |

### 7.7 LoginPage (`LoginPage.test.tsx`) — 5 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-LP-01 | Renders login button | Page mounted | Login button visible |
| F-LP-02 | Redirects to OAuth URL on click | Button clicked; authorize URL returned | `window.location.href` set to authorize URL |
| F-LP-03 | Handles missing authorize URL | Authorize endpoint returns empty URL | No redirect; no crash |
| F-LP-04 | Handles API error | Authorize endpoint returns 500 | Error handled gracefully |
| F-LP-05 | Shows loading during redirect | Button clicked | Loading state shown |

### 7.8 CallbackPage (`CallbackPage.test.tsx`) — 6 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-CB-01 | Parses access_token from URL hash | `#access_token=...` in hash | `login()` called with token |
| F-CB-02 | Navigates to `/` after login | Successful `login()` | `navigate('/')` called |
| F-CB-03 | Handles missing access_token | No token in hash | Error shown; no navigation |
| F-CB-04 | Handles login error | `login()` throws | Error shown |
| F-CB-05 | Shows loading state | During token processing | Loading indicator rendered |
| F-CB-06 | Calls login with correct token | Specific token value | `login()` receives exact token string |

### 7.9 RoleManagementPage (`RoleManagementPage.test.tsx`) — 7 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-RM-01 | Renders role list | Two roles loaded | Both role names visible |
| F-RM-02 | Sort descending on first click | Name column clicked once | Roles in descending alphabetical order |
| F-RM-03 | Sort ascending on second click | Name column clicked twice | Roles in ascending order |
| F-RM-04 | Opens create modal | Create button clicked | Create role modal visible |
| F-RM-05 | Create role calls POST | Form submitted | `POST /api/v1/role` called; modal closes |
| F-RM-06 | Delete opens confirmation modal | Delete button clicked | Confirmation modal shown |
| F-RM-07 | Confirmed delete calls DELETE | Confirm delete clicked | `DELETE /api/v1/role/{id}` called |

### 7.10 PermissionManagementPage (`PermissionManagementPage.test.tsx`) — 8 tests

| ID | Test Name | Scenario | Expected Result |
|----|-----------|----------|----------------|
| F-PM-01 | Renders permission list | Two permissions loaded | Both names visible |
| F-PM-02 | Sort descending on first click | Name column clicked once | Permissions in descending order |
| F-PM-03 | Sort ascending on second click | Name column clicked twice | Permissions in ascending order |
| F-PM-04 | Opens create modal | Create button clicked | Create permission modal visible |
| F-PM-05 | Create calls POST | Form submitted | `POST /api/v1/permission` called |
| F-PM-06 | Delete opens confirmation | Row delete clicked | Confirmation modal shown |
| F-PM-07 | Confirmed delete calls DELETE | Modal delete confirmed | `DELETE /api/v1/permission/{id}` called |
| F-PM-08 | Cancel delete dismisses modal | Modal cancel clicked | Modal closed; no DELETE call |
