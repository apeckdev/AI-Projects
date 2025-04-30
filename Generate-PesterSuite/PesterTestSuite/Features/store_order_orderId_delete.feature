Feature: /store/order/{orderId} - DELETE Endpoint (Delete purchase order by identifier.)

  Scenario: Basic successful DELETE request to /store/order/{orderId}
    Given a valid base API URL and necessary credentials
    When a DELETE request is sent to "/store/order/{orderId}"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
