Feature: /pet - POST Endpoint (Add a new pet to the store.)

  Scenario: Basic successful POST request to /pet
    Given a valid base API URL and necessary credentials
    When a POST request is sent to "/pet"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
