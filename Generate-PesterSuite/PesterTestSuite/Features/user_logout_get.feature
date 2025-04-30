Feature: /user/logout - GET Endpoint (Logs out current logged in user session.)

  Scenario: Basic successful GET request to /user/logout
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/user/logout"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
