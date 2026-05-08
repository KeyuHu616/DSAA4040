.PHONY: backend-dev frontend-dev dev backend-tests frontend-build web-validate

backend-dev:
	python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload

frontend-dev:
	cd frontend && npm run dev

dev:
	@trap 'kill 0' EXIT; \
	python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload & \
	cd frontend && npm run dev

backend-tests:
	python -m unittest discover -s backend/tests -v

frontend-build:
	cd frontend && npm run build

web-validate:
	python -m compileall backend
	python -m unittest discover -s backend/tests -v
	cd frontend && npm run build
