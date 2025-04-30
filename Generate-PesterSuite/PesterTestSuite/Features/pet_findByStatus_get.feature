Feature: /pet/findByStatus - GET Endpoint (Finds Pets by status.)

  Scenario: Basic successful GET request to /pet/findByStatus
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/pet/findByStatus"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
