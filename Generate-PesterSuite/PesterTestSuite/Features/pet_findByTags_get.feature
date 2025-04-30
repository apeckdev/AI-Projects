Feature: /pet/findByTags - GET Endpoint (Finds Pets by tags.)

  Scenario: Basic successful GET request to /pet/findByTags
    Given a valid base API URL and necessary credentials
    When a GET request is sent to "/pet/findByTags"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
