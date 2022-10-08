#! /usr/bin/env bash

set -e

CMDNAME=${0##*/}

usage() {
  exitcode="$1"
  cat <<USAGE >&2

Postprocess the output of openapi-generator

Usage:
  $CMDNAME -p PACKAGE_NAME

Options:
  -p, --package-name       The name to use for the generated package
  -w, --work-dir           The working directory used for generator output
  -h, --help               Show this message
USAGE
  exit "$exitcode"
}

main() {
  validate_inputs

  pushd $WORK_DIR

  # Upgrading to 5.4.0 - disabling the merge_generated_models command because:
  # the `ls "./${PACKAGE_NAME}"/models/*.py | grep -v __init__` command was getting stuck
  # as there weren't any files for it to process?
  # merge_generated_models
  delete_unused
  fix_any_of
  apply_formatters

  popd
}

validate_inputs() {
  if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: you need to provide --package-name argument"
    usage 2
  fi
}

merge_generated_models() {
  # Need to merge the generated models into a single file to prevent circular imports
  # shellcheck disable=SC2046
  # shellcheck disable=SC2010
  cat $(ls "./${PACKAGE_NAME}"/models/*.py | grep -v __init__) > "./${PACKAGE_NAME}/models.py"
  rm -r "./${PACKAGE_NAME}"/models >/dev/null 2>&1 || true
}

delete_unused() {
  # Delete empty folder
  rm -r "${PACKAGE_NAME}"/test >/dev/null 2>&1 || true

  rm "${PACKAGE_NAME}"/rest.py >/dev/null 2>&1 || true
  rm "${PACKAGE_NAME}"/configuration.py >/dev/null 2>&1 || true
}

fix_any_of() {
  find . -name "*.py" -exec sed -i.bak "s/AnyOf[a-zA-Z0-9]*/Any/" {} \;
  find . -name "*.md" -exec sed -i.bak "s/AnyOf[a-zA-Z0-9]*/Any/" {} \;
  find . -name "*.bak" -exec rm {} \;
}

apply_formatters() {
  autoflake --remove-all-unused-imports --recursive --remove-unused-variables --in-place "${PACKAGE_NAME}" --exclude=__init__.py
  isort --float-to-top -w 120 -m 3 --trailing-comma --force-grid-wrap 0 --combine-as -p "${PACKAGE_NAME}" "${PACKAGE_NAME}"
  
  # Upgrading to 5.4.0 - disabling the `black` command because:
  # it was failing with: 
  # `ImportError: cannot import name 'GitWildMatchPatternError' from 'pathspec.patterns.gitwildmatch'`
  # black --fast -l 120 --target-version py37 "${PACKAGE_NAME}"
}

while [ $# -gt 0 ]; do
  case "$1" in
  -p | --package-name)
    PACKAGE_NAME=$2
    shift 2
    ;;
  -w | --work-dir)
    WORK_DIR=$2
    shift 2
    ;;
  -h | --help)
    usage 0
    ;;
  *)
    echo "Unknown argument: $1"
    usage 1
    ;;
  esac
done

main
