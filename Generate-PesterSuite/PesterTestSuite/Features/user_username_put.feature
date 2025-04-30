Feature: /user/{username} - PUT Endpoint (Update user resource.)

  Scenario: Basic successful PUT request to /user/{username}
    Given a valid base API URL and necessary credentials
    When a PUT request is sent to "/user/{username}"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
