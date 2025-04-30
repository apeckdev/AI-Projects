Feature: /pet/{petId} - GET Endpoint (Find pet by ID.)

  Scenario: Basic successful GET request to /pet/{petId}
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/pet/{petId}"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
