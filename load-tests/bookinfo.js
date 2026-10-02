import http from 'k6/http';
import { check } from 'k6';

http.setResponseCallback(http.expectedStatuses(200));

export const options = {
  scenarios: {
    bookinfo: {
      executor: 'constant-vus',
      vus: Number(__ENV.TOTAL_VUS),
      duration: `${__ENV.DURATION_SECONDS}s`,
      gracefulStop: '30s',
    },
  },
  maxRedirects: 0,
  insecureSkipTLSVerify: false,
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>=0.99'],
  },
};

export default function () {
  const response = http.get(__ENV.TARGET_URL);
  check(response, { 'HTTP 200': (value) => value.status === 200 });
}
