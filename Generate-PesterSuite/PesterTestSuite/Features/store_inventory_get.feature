Feature: /store/inventory - GET Endpoint (Returns pet inventories by status.)

  Scenario: Basic successful GET request to /store/inventory
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/store/inventory"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
