Feature: /user/login - GET Endpoint (Logs user into the system.)

  Scenario: Basic successful GET request to /user/login
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/user/login"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
