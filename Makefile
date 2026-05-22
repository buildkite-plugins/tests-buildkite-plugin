all: test lint

test:
	docker compose run --rm tests

lint:
	docker compose run --rm lint
