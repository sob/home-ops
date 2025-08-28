import http from 'k6/http';
import { check, sleep } from 'k6';

// Plex internal availability test
// Tests Plex accessibility from within the cluster via LoadBalancer IP
// Uses k6 built-in metrics with tags for Prometheus export

const serviceName = 'plex-internal';
const plexLbIp = __ENV.PLEX_LB_IP || '10.1.100.204';

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    'checks{service:plex-internal}': ['rate>0.95'],
    'http_req_duration{service:plex-internal}': ['p(95)<3000'],
    'http_req_failed{service:plex-internal}': ['rate<0.10'],
  },
  tags: {
    service: serviceName,
    test_type: 'synthetic',
  },
};

export default function () {
  // Test internal LoadBalancer IP connectivity
  const tags = {
    service: serviceName,
  };
  
  // Test server identity endpoint first
  const identityResponse = http.get(`http://${plexLbIp}:32400/identity`, { 
    tags: Object.assign({}, tags, { endpoint_type: 'identity' })
  });
  
  check(identityResponse, {
    'plex_identity_accessible': (r) => r.status === 200,
    'plex_is_running': (r) => r.body && (r.body.includes('machineIdentifier') || r.body.includes('MediaContainer')),
  }, tags);
  
  // Test library sections
  const sectionsResponse = http.get(`http://${plexLbIp}:32400/library/sections`, {
    tags: Object.assign({}, tags, { endpoint_type: 'library_sections' })
  });
  
  check(sectionsResponse, {
    'plex_libraries_accessible': (r) => r.status === 200,
    'plex_has_libraries': (r) => r.body && r.body.includes('Directory'),
  }, tags);
  
  // Test recently added
  const recentResponse = http.get(`http://${plexLbIp}:32400/library/recentlyAdded?X-Plex-Container-Size=5`, {
    tags: Object.assign({}, tags, { endpoint_type: 'recently_added' })
  });
  
  check(recentResponse, {
    'plex_recent_accessible': (r) => r.status === 200,
    'plex_recent_has_content': (r) => r.body && r.body.includes('MediaContainer'),
  }, tags);
  
  sleep(5); // Check every 5 seconds for critical internal service
}