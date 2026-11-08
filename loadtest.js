import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 100,
  duration: '1m',
};

export default function () {
  const url = 'url_to_test'; // Replace with the actual URL you want to test

  const res = http.get(url);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}










