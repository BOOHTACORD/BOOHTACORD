# Isolated API baseline

This optional runner exercises login, topology, text history and search using
synthetic accounts on an explicitly confirmed isolated deployment. It does not
publish messages, generate media, or establish a supported capacity profile.
Use the owned fixture runners under `tools/load` for capacity acceptance.

Create a private JSON file outside the repository with an `accounts` array of
objects containing only `login` and `password`. Use one distinct synthetic
account per virtual user. Never use production accounts or a production target.

```sh
python -m tools.qa.backend_load.run --target http://127.0.0.1:4820 \
  --accounts /private/synthetic-accounts.json --channel-id FIXTURE_CHANNEL_UUID \
  --vus 2 --duration-seconds 30 --ramp-seconds 5 \
  --confirm ISOLATED_TEST_DEPLOYMENT --report /private/api-baseline.json
```

Targets must be loopback, RFC1918/ULA private addresses, or deliberately configured
reserved `.test` hostnames. The operator remains responsible for ownership of
the selected isolated service. Every HTTP redirect is rejected, including a
same-origin redirect; an API 3xx is recorded as an error rather than followed.
Only aggregate operation statuses and timings are written. Account secrets and
response bodies are not stored in the report.

Run the regression suite without opening a real deployment:

```sh
python -m unittest discover -s tools/qa/backend_load -t .
```
