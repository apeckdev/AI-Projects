Feature: /user/{username} - GET Endpoint (Get user by user name.)

  Scenario: Basic successful GET request to /user/{username}
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/user/{username}"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
