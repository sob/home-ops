import http from 'k6/http';
import { check, sleep } from 'k6';

// Plex external availability test
// Tests Plex accessibility via Cloudflare tunnel
// Uses k6 built-in metrics with tags for Prometheus export

const serviceName = 'plex-external';

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    'checks{service:plex-external}': ['rate>0.95'],
    'http_req_duration{service:plex-external}': ['p(95)<3000'],
    'http_req_failed{service:plex-external}': ['rate<0.10'],
  },
  tags: {
    service: serviceName,
    test_type: 'synthetic',
  },
};

export default function () {
  const domain = __ENV.DOMAIN || '56kbps.io';
  const tags = {
    service: serviceName,
  };
  
  // Test external access via Cloudflare tunnel
  const externalResponse = http.get(`https://plex.${domain}/web/index.html`, {
    tags: Object.assign({}, tags, { endpoint_type: 'web_interface' })
  });
  
  check(externalResponse, {
    'plex_web_accessible': (r) => r.status === 200,
    'plex_web_has_content': (r) => r.body && r.body.includes('plex'),
  }, tags);
  
  // Test external identity endpoint (public, no auth required)
  const identityResponse = http.get(`https://plex.${domain}/identity`, {
    tags: Object.assign({}, tags, { endpoint_type: 'identity' })
  });
  
  check(identityResponse, {
    'plex_identity_accessible': (r) => r.status === 200,
    'plex_server_identified': (r) => r.body && (r.body.includes('machineIdentifier') || r.body.includes('MediaContainer')),
  }, tags);
  
  sleep(5); // Check every 5 seconds
}