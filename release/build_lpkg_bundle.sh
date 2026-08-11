#!/bin/bash

source ../_env_common.sh
source ../_liferay_common.sh
source ../_release_common.sh
source ./_git.sh
source ./_lpkg.sh
source ./_package.sh
source ./_product.sh

function check_usage {
	if [ "${LIFERAY_RELEASE_DEVELOPER_MODE}" == "true" ]
	then
		LIFERAY_RELEASE_UPLOAD="false"
	fi

	if [ -z "${LIFERAY_RELEASE_PRODUCT_VERSION}" ] ||
	   ([ -z "${LIFERAY_RELEASE_GCS_TOKEN}" ] &&
	   [ "$(get_environment_type)" == "local" ] &&
	   [ "${LIFERAY_RELEASE_UPLOAD}" == "true" ])
	then
		print_help
	fi

	lc_check_utils 7z ant blade gcloud git || exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	LIFERAY_RELEASE_PRODUCT_NAME=dxp

	_PRODUCT_VERSION=${LIFERAY_RELEASE_PRODUCT_VERSION}

	if ! is_quarterly_release
	then
		lc_log ERROR "The product version ${_PRODUCT_VERSION} is not a quarterly release."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ -z "${LIFERAY_RELEASE_LPKG_APP_NAME}" ]
	then
		LIFERAY_RELEASE_LPKG_APP_NAME="digital-sales-room"
	fi

	if [ -z "${LIFERAY_RELEASE_GIT_REF}" ]
	then
		LIFERAY_RELEASE_GIT_REF="master"
	fi

	_BUILD_TIMESTAMP=$(date +%s)
	_LPKG_VERSION=$(get_lpkg_version)

	_RELEASE_TOOL_DIR=$(dirname "$(readlink /proc/$$/fd/255 2> /dev/null)")

	lc_cd "${_RELEASE_TOOL_DIR}"

	mkdir --parents release-data

	lc_cd release-data

	_RELEASE_ROOT_DIR=${PWD}

	_BUILD_DIR="${_RELEASE_ROOT_DIR}/build"
	_PROJECTS_DIR="/opt/dev/projects/github"

	if [ ! -d "${_PROJECTS_DIR}" ]
	then
		_PROJECTS_DIR="${_RELEASE_ROOT_DIR}/dev/projects"
	fi

	LIFERAY_COMMON_LOG_DIR=${_BUILD_DIR}

	LIFERAY_PORTAL_REPOSITORY_NAME="liferay-portal-ee"
	LIFERAY_PORTAL_REPOSITORY_OWNER="brianchandotcom"

	_LPKG_APP_DIR="${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/dxp/apps/${LIFERAY_RELEASE_LPKG_APP_NAME}"
}

function lc_time_run_error {
	if [ -z "${_BUNDLES_DIR}" ]
	then
		return
	fi

	lc_log INFO "Stopping Tomcat because ${LC_TIME_RUN_ERROR_FUNCTION} failed."

	stop_tomcat &> /dev/null
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	if [ "$(get_environment_type)" != "local" ]
	then
		export ANT_OPTS="-Xmx10G"
	fi

	check_usage

	print_variables

	if [ "${_PROJECTS_DIR}" == "${_RELEASE_ROOT_DIR}/dev/projects" ]
	then
		lc_time_run clone_repository "${LIFERAY_PORTAL_REPOSITORY_NAME}"
	fi

	lc_time_run clean_portal_repository

	lc_time_run update_portal_repository

	lc_time_run set_git_sha

	lc_time_run build_lpkg

	print_lpkg_app_info

	lc_time_run download_release_bundle

	lc_time_run extract_release_bundle

	lc_time_run deploy_lpkg

	lc_time_run start_lpkg_bundle

	lc_time_run assert_lpkg_deployment

	lc_time_run stop_tomcat

	lc_time_run package_lpkg_bundle

	lc_time_run generate_checksum_files

	lc_time_run upload_lpkg_bundle

	local end_time=$(date +%s)

	local seconds=$((end_time - _BUILD_TIMESTAMP))

	lc_log INFO "Completed building the ${LIFERAY_RELEASE_LPKG_APP_NAME} ${_LPKG_VERSION} bundle of ${_PRODUCT_VERSION} in $(lc_echo_time "${seconds}") on $(date)."
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_PRODUCT_VERSION=<product version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_DEVELOPER_MODE (optional): Set this to \"true\" to run the script as a local development build. Forces LIFERAY_RELEASE_UPLOAD to \"false\"."
	echo "    LIFERAY_RELEASE_GCS_TOKEN (optional): *.json file containing the token to authenticate with Google Cloud Storage"
	echo "    LIFERAY_RELEASE_GIT_REF (optional): Git ref to build the LPKG file from. Defaults to \"master\", which is not the ref the release candidate bundle was built from."
	echo "    LIFERAY_RELEASE_LPKG_APP_NAME (optional): Name of the app to build the LPKG file from. Defaults to \"digital-sales-room\"."
	echo "    LIFERAY_RELEASE_PRODUCT_VERSION: Product version of the release candidate bundle to add the LPKG file to"
	echo "    LIFERAY_RELEASE_UPLOAD (optional): Set this to \"true\" to upload artifacts"
	echo ""
	echo "Example: LIFERAY_RELEASE_PRODUCT_VERSION=2026.q3.1 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function print_variables {
	echo "To reproduce this build locally, execute the following command in liferay-docker/release:"

	local environment=$( \
		set | \
		grep --invert-match "LIFERAY_RELEASE_GCS_TOKEN" | \
		grep --invert-match "LIFERAY_RELEASE_UPLOAD" | \
		grep --regexp="^LIFERAY_RELEASE" | \
		tr "\n" " ")

	echo "${environment}LIFERAY_RELEASE_DEVELOPER_MODE=true ./build_lpkg_bundle.sh"
	echo ""
}

main
