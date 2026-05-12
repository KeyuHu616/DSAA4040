.PHONY: check-environment static-validate bootstrap onboard-team-a onboard-team-b offboard-team-a offboard-team-b test

check-environment:
	bash scripts/check-environment.sh

static-validate:
	bash scripts/static-validate.sh

bootstrap:
	bash scripts/bootstrap-cluster.sh

onboard-team-a:
	bash scripts/onboard-team.sh team-a

onboard-team-b:
	bash scripts/onboard-team.sh team-b

offboard-team-a:
	bash scripts/offboard-team.sh team-a

offboard-team-b:
	bash scripts/offboard-team.sh team-b

test:
	bash scripts/run-tests.sh
