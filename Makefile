NAME ?= cray-baremetal-etcd-backup
CHART_PATH ?= kubernetes

HELM_UNITTEST_IMAGE ?= quintush/helm-unittest:3.3.0-0.2.5

all : chart
chart: chart_test chart_package

chart_package:
	helm dep up ${CHART_PATH}/${NAME}
	helm package ${CHART_PATH}/${NAME} -d ${CHART_PATH}/.packaged $(if ${CHART_VERSION},--version ${CHART_VERSION},)

chart_test:
	helm lint "${CHART_PATH}/${NAME}"
	docker run --rm -v ${PWD}/${CHART_PATH}:/apps ${HELM_UNITTEST_IMAGE} -3 ${NAME}
