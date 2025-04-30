Feature: /pet - PUT Endpoint (Update an existing pet.)

  Scenario: Basic successful PUT request to /pet
    Given a valid base API URL and necessary credentials
    When a PUT request is sent to "/pet"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
