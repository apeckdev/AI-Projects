Feature: User Management and System Tests

  Background:
    Given the system is initialized

  Scenario: Add New User
    When I add a user with the following details:
      | Name        | Role              | Location | Access Level |
      | Frank       | SysAdmin          | Berlin   | 5            |
      | Grace Hopper| Pioneer           | Space    | 9            |
      | "Test, User"| Quoted Role       | Here     | 1            | # Example with quotes and comma

  Scenario: Verify System Status
    Given the monitoring agent is active
    Then the status of the following systems should be 'Online':
      | System ID | Hostname    | Check Type |
      | SRV001    | web01.local | Ping       |
      | SRV002    | db01.local  | Service    |
      | SRV003    | app01.local | Heartbeat  |

  Scenario Outline: Login Attempts
    When a user attempts to login with <Username> and <Password>
    Then the expected login result is <Result>

    Examples: Valid Credentials
      | Username | Password   | Result  | Notes                |
      | alice    | pass@123   | Success | Standard user        |
      | bob      | complex!Pwd| Success |                      | # Empty cell example
      | charlie  | testing    | Success | Trailing space user  |

    Examples: Invalid Credentials
      | Username | Password | Result |
      |eve       | wrong    | Fail   |
      | frank    | badpass  | Fail   |