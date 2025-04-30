Feature: /user - POST Endpoint (Create user.)

  Scenario: Basic successful POST request to /user
    Given a valid base API URL and necessary credentials
    When a POST request is sent to "/user"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
