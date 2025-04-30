Feature: /pet/{petId} - DELETE Endpoint (Deletes a pet.)

  Scenario: Basic successful DELETE request to /pet/{petId}
    Given a valid base API URL and necessary credentials
    When a DELETE request is sent to "/pet/{petId}"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
