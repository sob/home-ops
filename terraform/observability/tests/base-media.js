import http from 'k6/http';
import { check, sleep } from 'k6';

// Base media services test - Generic API test for media stack services
// Uses k6 built-in metrics with tags for Prometheus export
// Required ENV vars:
// - SERVICE_NAME: Name of the service (e.g., "jellyseerr")
// - SERVICE_URL: Full URL to test (e.g., "https://jellyseerr.56kbps.io")
// Optional ENV vars:
// - API_ENDPOINT: API endpoint to test (default: "/api/v1/status", set to "none" to skip)
// - HEALTH_ENDPOINT: Health check endpoint (default: "/", set to "none" to skip)
// - CHECK_STRING: String to check for in response (default: service name)
// - SLEEP_DURATION: Sleep duration between checks in seconds (default: "10")
// - API_KEY: API key for authentication (if required)

const serviceName = __ENV.SERVICE_NAME || 'generic';

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    [`checks{service:${serviceName}}`]: [{
      threshold: 'rate>0.95',
      abortOnFail: true,
    }],
    [`http_req_duration{service:${serviceName}}`]: ['p(95)<3000'],
    [`http_req_failed{service:${serviceName}}`]: [{
      threshold: 'rate<0.10',
      abortOnFail: true,
    }],
  },
  tags: {
    service: serviceName,
    test_type: 'synthetic',
  },
};

export default function () {
  const serviceUrl = __ENV.SERVICE_URL;
  const apiEndpoint = __ENV.API_ENDPOINT || '/api/v1/status';
  const healthEndpoint = __ENV.HEALTH_ENDPOINT || '/';
  const checkString = __ENV.CHECK_STRING || serviceName;
  const sleepDuration = parseInt(__ENV.SLEEP_DURATION || '10');
  const apiKey = __ENV.API_KEY;
  
  // Common request tags
  const tags = {
    service: serviceName,
  };
  
  // Health check
  if (healthEndpoint && healthEndpoint !== 'none') {
    const healthResponse = http.get(`${serviceUrl}${healthEndpoint}`, {
      tags: Object.assign({}, tags, { endpoint_type: 'health' })
    });
    
    check(healthResponse, {
      [`health_status_ok`]: (r) => r.status === 200,
      [`health_has_content`]: (r) => r.body && (checkString ? r.body.includes(checkString) : r.body.length > 0),
    }, tags);
  }
  
  // API endpoint check
  if (apiEndpoint && apiEndpoint !== 'none') {
    const headers = apiKey ? { 'X-Api-Key': apiKey } : {};
    const apiResponse = http.get(`${serviceUrl}${apiEndpoint}`, {
      headers: headers,
      tags: Object.assign({}, tags, { endpoint_type: 'api' })
    });
    
    const apiChecks = check(apiResponse, {
      [`api_status_ok`]: (r) => r.status === 200,
      [`api_has_expected_content`]: (r) => {
        if (!r.body) return false;
        // Check for JSON response
        try {
          const json = JSON.parse(r.body);
          return json !== null && typeof json === 'object';
        } catch {
          // If not JSON, check for the check string
          return checkString ? r.body.includes(checkString) : true;
        }
      },
    }, tags);
  }
  
  // Test additional endpoints if provided
  const additionalEndpoints = __ENV.ADDITIONAL_ENDPOINTS;
  if (additionalEndpoints && additionalEndpoints !== 'none') {
    const endpoints = additionalEndpoints.split(',');
    endpoints.forEach(endpoint => {
      const response = http.get(`${serviceUrl}${endpoint}`, {
        tags: Object.assign({}, tags, { endpoint_type: 'additional', endpoint: endpoint })
      });
      
      check(response, {
        [`additional_endpoint_ok`]: (r) => r.status === 200,
      }, tags);
    });
  }
  
  sleep(sleepDuration);
}