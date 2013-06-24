var metrics =
[
  {
    "target": "web.1.stream.eps.clients"
  },
  {
    "target": "web.1.stream.detail.clients"
  },
  {
    "target": "web.1.stream.raw.clients"
  },
  {
    "alias": "feeder updates",
    "target": "feeder.updates.rate_per_second",
    "description": "updates being pushed from feeder to redis",
    "unit": "/sec",
    "warning": 100,
    "critical": 50
  },
  {
    "alias": "redis_mem",
    "target": "feeder.redis.used_memory_kb",
    "unit": "KB",
    "description": "memory in usage on redis instance",
    "warning": 4000,
    "critical": 5000
  }
];
