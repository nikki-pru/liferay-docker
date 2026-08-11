#!/bin/bash

source ../_release_common.sh
source ./_product.sh

function assert_lpkg_deployment {
	local bundle_symbolic_names=$(_get_lpkg_bundle_symbolic_names)

	if [ -z "${bundle_symbolic_names}" ]
	then
		lc_log ERROR "Unable to read the app artifacts of ${LIFERAY_RELEASE_LPKG_APP_NAME} ${_LPKG_VERSION} from ${_LPKG_APP_DIR}/app.changelog."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local modules_info=$(blade sh lb -s)

	if [ -z "${modules_info}" ]
	then
		lc_log ERROR "Unable to list the modules of the ${_PRODUCT_VERSION} bundle."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local exit_code=${LIFERAY_COMMON_EXIT_CODE_OK}

	local bundle_symbolic_name

	while IFS= read -r bundle_symbolic_name
	do
		_assert_module_state "${bundle_symbolic_name}" "${modules_info}"

		if [[ "${?}" -ne "${LIFERAY_COMMON_EXIT_CODE_OK}" ]]
		then
			exit_code=${LIFERAY_COMMON_EXIT_CODE_BAD}
		fi
	done <<< "${bundle_symbolic_names}"

	if [[ "${exit_code}" -ne "${LIFERAY_COMMON_EXIT_CODE_OK}" ]]
	then
		lc_log ERROR "The LPKG file ${_LPKG_FILE_NAME} was not deployed correctly on the ${_PRODUCT_VERSION} bundle."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_log INFO "The LPKG file ${_LPKG_FILE_NAME} was deployed correctly on the ${_PRODUCT_VERSION} bundle."
}

function build_lpkg {
	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}"

	ant setup-sdk

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to set up the SDK."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	ant setup-libs

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to set up the libraries."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	set_up_profile

	local dist_dir="${_LPKG_APP_DIR}/dist"

	rm --force --recursive "${dist_dir}"

	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules"

	ant build-app-unlicensed-lpkg -Dapp.name="${LIFERAY_RELEASE_LPKG_APP_NAME}" -Dapp.version="${_LPKG_VERSION}" -Dcheck.stale.artifacts.skip=true

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to build the ${LIFERAY_RELEASE_LPKG_APP_NAME} ${_LPKG_VERSION} LPKG file."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local app_version=$(lc_get_property "${_LPKG_APP_DIR}/app.properties" "app.marketplace.version")

	if [ "${app_version}" != "${_LPKG_VERSION}" ]
	then
		lc_log ERROR "The app.marketplace.version property of ${LIFERAY_RELEASE_LPKG_APP_NAME} is ${app_version} instead of ${_LPKG_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local lpkg_file_path=$(find "${dist_dir}" -name "*.lpkg" -type f | head --lines=1)

	if [ -z "${lpkg_file_path}" ]
	then
		lc_log ERROR "No LPKG file was built in ${dist_dir}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	_LPKG_FILE_NAME=$(basename "${lpkg_file_path}")

	mkdir --parents "${_BUILD_DIR}/lpkg"

	cp "${lpkg_file_path}" "${_BUILD_DIR}/lpkg"

	lc_log INFO "The LPKG file ${_LPKG_FILE_NAME} is held at ${_BUILD_DIR}/lpkg."
}

function deploy_lpkg {
	local lpkg_file_path="${_BUILD_DIR}/lpkg/${_LPKG_FILE_NAME}"

	if [ ! -f "${lpkg_file_path}" ]
	then
		lc_log ERROR "The LPKG file ${lpkg_file_path} does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_log INFO "Deploying ${_LPKG_FILE_NAME} to ${_BUNDLES_DIR}/deploy."

	mkdir --parents "${_BUNDLES_DIR}/deploy"

	cp "${lpkg_file_path}" "${_BUNDLES_DIR}/deploy"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to deploy ${_LPKG_FILE_NAME} to ${_BUNDLES_DIR}/deploy."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function download_release_bundle {
	_RELEASE_CANDIDATE_BUCKET=$(_get_release_candidate_bucket)

	if [ -z "${_RELEASE_CANDIDATE_BUCKET}" ]
	then
		lc_log ERROR "Unable to find a release candidate for ${_PRODUCT_VERSION} in gs://liferay-releases-candidates."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_log INFO "Found the release candidate ${_RELEASE_CANDIDATE_BUCKET}."

	_RELEASE_BUNDLE_FILE_NAME=$(gcloud storage cat "${_RELEASE_CANDIDATE_BUCKET}.lfrrelease-tomcat-bundle")

	if [ -z "${_RELEASE_BUNDLE_FILE_NAME}" ]
	then
		lc_log ERROR "Unable to read ${_RELEASE_CANDIDATE_BUCKET}.lfrrelease-tomcat-bundle."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	mkdir --parents "${_BUILD_DIR}/bundle"

	lc_log INFO "Downloading ${_RELEASE_CANDIDATE_BUCKET}${_RELEASE_BUNDLE_FILE_NAME}."

	gcloud storage cp "${_RELEASE_CANDIDATE_BUCKET}${_RELEASE_BUNDLE_FILE_NAME}" "${_BUILD_DIR}/bundle"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to download ${_RELEASE_BUNDLE_FILE_NAME}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function extract_release_bundle {
	local extract_dir="${_BUILD_DIR}/bundle"

	rm --force --recursive "${extract_dir}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	7z x -o"${extract_dir}" "${extract_dir}/${_RELEASE_BUNDLE_FILE_NAME}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to extract ${_RELEASE_BUNDLE_FILE_NAME}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	_BUNDLES_DIR="${extract_dir}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	if [ ! -d "${_BUNDLES_DIR}/tomcat" ]
	then
		lc_log ERROR "The extracted bundle ${_BUNDLES_DIR} does not contain a Tomcat directory."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_log INFO "The ${_PRODUCT_VERSION} bundle is extracted to ${_BUNDLES_DIR}."
}

function get_lpkg_version {
	local release_year=$(get_release_year)

	echo "$((release_year - 2000)).$(get_release_quarter).$(get_release_patch_version)"
}

function package_lpkg_bundle {
	_LPKG_BUNDLE_FILE_NAME="$(echo "${_RELEASE_BUNDLE_FILE_NAME}" | sed --expression "s/\.7z$//")-${LIFERAY_RELEASE_LPKG_APP_NAME}-${_LPKG_VERSION}.7z"

	if [ "${_LPKG_BUNDLE_FILE_NAME}" == "${_RELEASE_BUNDLE_FILE_NAME}" ]
	then
		lc_log ERROR "The LPKG bundle file name is the same as the ${_PRODUCT_VERSION} bundle file name."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	rm --force "${_BUNDLES_DIR}/portal-ext.properties"

	rm --force --recursive "${_BUILD_DIR}/release"

	mkdir --parents "${_BUILD_DIR}/release"

	lc_cd "$(dirname "${_BUNDLES_DIR}")"

	7z a "${_BUILD_DIR}/release/${_LPKG_BUNDLE_FILE_NAME}" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to package ${_LPKG_BUNDLE_FILE_NAME}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_log INFO "The LPKG bundle is packaged at ${_BUILD_DIR}/release/${_LPKG_BUNDLE_FILE_NAME}."
}

function print_lpkg_app_info {
	echo ""
	echo "App title: $(lc_get_property "${_LPKG_APP_DIR}/app.properties" "app.marketplace.title")"
	echo "App version: ${_LPKG_VERSION}"
	echo "App portal build: $(lc_get_property "${_LPKG_APP_DIR}/app.properties" "app.portal.build")"
	echo "App Git ID: $(lc_get_property "${_LPKG_APP_DIR}/app.changelog" "app.git.id-${_LPKG_VERSION}")"
	echo "App change log: $(lc_get_property "${_LPKG_APP_DIR}/app.changelog" "app.change.log-${_LPKG_VERSION}")"
	echo ""
	echo "App artifacts:"

	local app_artifact

	while IFS= read -r app_artifact
	do
		echo "    ${app_artifact}"
	done <<< "$(_get_lpkg_app_artifacts)"

	echo ""
}

function start_lpkg_bundle {
	rm --force "${_BUILD_DIR}/warm-up-tomcat"

	_LPKG_DEPLOYMENT_LOG_FILE="${_BUILD_DIR}/log_$(date +%s)_lpkg_deployment.txt"

	warm_up_tomcat "print-startup-logs" > "${_LPKG_DEPLOYMENT_LOG_FILE}"

	if [[ "${?}" -ne "${LIFERAY_COMMON_EXIT_CODE_OK}" ]]
	then
		lc_log ERROR "Unable to warm up the ${_PRODUCT_VERSION} bundle with ${_LPKG_FILE_NAME} deployed."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	echo "include-and-override=portal-developer.properties" > "${_BUNDLES_DIR}/portal-ext.properties"

	start_tomcat "print-startup-logs" >> "${_LPKG_DEPLOYMENT_LOG_FILE}"

	if [[ "${?}" -ne "${LIFERAY_COMMON_EXIT_CODE_OK}" ]]
	then
		lc_log ERROR "Unable to start the ${_PRODUCT_VERSION} bundle with ${_LPKG_FILE_NAME} deployed."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function upload_lpkg_bundle {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}/release"

	local file

	for file in *
	do
		if [ -f "${file}" ]
		then
			lc_log INFO "Copying ${file} to ${_RELEASE_CANDIDATE_BUCKET}."

			gcloud storage cp "${_BUILD_DIR}/release/${file}" "${_RELEASE_CANDIDATE_BUCKET}"

			if [[ "${?}" -ne 0 ]]
			then
				lc_log ERROR "Unable to upload ${file} to ${_RELEASE_CANDIDATE_BUCKET}."

				return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
			fi
		fi
	done
}

function _assert_module_state {
	local bundle_symbolic_name=${1}
	local modules_info=${2}

	local module_info=$( \
		echo "${modules_info}" | \
		grep --extended-regexp "\|[[:space:]]*${bundle_symbolic_name} \(" | \
		head --lines=1)

	if [ -z "${module_info}" ]
	then
		lc_log ERROR "The module ${bundle_symbolic_name} of ${_LPKG_FILE_NAME} was not installed."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local module_state=$( \
		echo "${module_info}" | \
		cut --delimiter="|" --fields=2 | \
		xargs)

	if [ "${module_state}" == "Active" ] || [ "${module_state}" == "Resolved" ]
	then
		lc_log INFO "The module ${bundle_symbolic_name} is in the ${module_state} state."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	lc_log ERROR "The module ${bundle_symbolic_name} is in the ${module_state} state."

	local module_id=$( \
		echo "${module_info}" | \
		cut --delimiter="|" --fields=1 | \
		xargs)

	lc_log INFO "OSGI diagnostics: $( \
		blade sh diag "${module_id}" | \
		tail --lines=+3 | \
		xargs)"

	if grep --quiet "${bundle_symbolic_name}" "${_LPKG_DEPLOYMENT_LOG_FILE}"
	then
		lc_log INFO "Deployment logs for ${bundle_symbolic_name}:"

		grep "${bundle_symbolic_name}" "${_LPKG_DEPLOYMENT_LOG_FILE}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function _get_lpkg_app_artifacts {
	lc_get_property "${_LPKG_APP_DIR}/app.changelog" "app.artifacts-${_LPKG_VERSION}" | \
		tr "," "\n" | \
		sort | \
		uniq
}

function _get_lpkg_bundle_symbolic_names {
	_get_lpkg_app_artifacts | sed --regexp-extended --expression "s/-[0-9]+(\.[0-9]+)*(\.[A-Za-z0-9_-]+)?\.jar$//"
}

function _get_release_candidate_bucket {
	gcloud storage ls "gs://liferay-releases-candidates/" | \
		grep --extended-regexp "/${_PRODUCT_VERSION}-[0-9]+/$" | \
		sort | \
		tail --lines=1
}
