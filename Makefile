NAME ?= cray-baremetal-etcd-backup

CHARTDIR ?= kubernetes

CHART_METADATA_IMAGE ?= artifactory.algol60.net/csm-docker/stable/chart-metadata
YQ_IMAGE ?= artifactory.algol60.net/docker.io/mikefarah/yq:4
HELM_IMAGE ?= artifactory.algol60.net/csm-docker/stable/docker.io/alpine/helm:3.9.4
HELM_UNITTEST_IMAGE ?= artifactory.algol60.net/csm-docker/stable/docker.io/quintush/helm-unittest:latest
HELM_DOCS_IMAGE ?= artifactory.algol60.net/csm-docker/stable/docker.io/jnorwood/helm-docs:v1.5.0

all: package test

helm:
	docker run --rm \
	    --user $(shell id -u):$(shell id -g) \
	    --mount type=bind,src="$(shell pwd)",dst=/src \
	    -w /src \
	    -e HELM_CACHE_HOME=/src/.helm/cache \
	    -e HELM_CONFIG_HOME=/src/.helm/config \
	    -e HELM_DATA_HOME=/src/.helm/data \
	    $(HELM_IMAGE) \
	    $(CMD)

package: ${CHARTDIR}/.packaged
	CMD="dep up ${CHARTDIR}/${NAME}" $(MAKE) helm
	CMD="package ${CHARTDIR}/${NAME} -d ${CHARTDIR}/.packaged $(if ${CHART_VERSION},--version ${CHART_VERSION},)" $(MAKE) helm

${CHARTDIR}/.packaged:
	mkdir -p ${CHARTDIR}/.packaged

test:
	CMD="lint ${CHARTDIR}/${NAME}" $(MAKE) helm
	docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		-v ${PWD}/${CHARTDIR}:/apps \
		${HELM_UNITTEST_IMAGE} \
		${NAME}

extract-images:
	{ CMD="template release ${CHARTDIR}/${NAME} --dry-run --replace --dependency-update" $(MAKE) -s helm; \
	  echo '---' ; \
	  CMD="show chart ${CHARTDIR}/${NAME}" $(MAKE) -s helm | docker run --rm -i $(YQ_IMAGE) e -N '.annotations."artifacthub.io/images"' - ; \
	} | docker run --rm -i $(YQ_IMAGE) e -N '.. | .image? | select(.)' - | sort -u

snyk:
	$(MAKE) -s extract-images | xargs --verbose -n 1 snyk container test

gen-docs:
	docker run --rm \
	    --user $(shell id -u):$(shell id -g) \
	    --mount type=bind,src="$(shell pwd)",dst=/src \
	    -w /src \
	    $(HELM_DOCS_IMAGE) \
	    helm-docs --chart-search-root=$(CHARTDIR)

clean:
	$(RM) -r ${CHARTDIR}/.packaged .helm
