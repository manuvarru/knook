#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h:h}

version=${1:-${KNOOK_VERSION:-}}
app_path=${2:-${KNOOK_APP_PATH:-"${repo_root}/build/export/Knook Ita.app"}}

if [[ -z "${version}" ]]; then
  echo "Usage: ${0} <version> [app-path]" >&2
  exit 1
fi

if [[ ! -d "${app_path}" ]]; then
  echo "Missing app bundle at ${app_path}" >&2
  exit 1
fi

output_dir="${repo_root}/build"
staging_dir="${output_dir}/dmg"
output_dmg="${output_dir}/Knook-Ita-${version}.dmg"

rm -rf "${staging_dir}"
mkdir -p "${staging_dir}"
cp -R "${app_path}" "${staging_dir}/Knook Ita.app"
ln -s /Applications "${staging_dir}/Applications"

# Set the custom icon on the staging directory (so the mounted volume gets the custom icon)
swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(byReferencingFile: "'"${script_dir}/AppIcon.icns"'"), forFile: "'"${staging_dir}"'", options: [])'

# Set the custom icon on the app bundle (so the app inside the DMG does not have the grey border)
swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(byReferencingFile: "'"${script_dir}/AppIcon.icns"'"), forFile: "'"${staging_dir}/Knook Ita.app"'", options: [])'

rm -f "${output_dmg}"

hdiutil create \
  -volname "Knook Ita" \
  -srcfolder "${staging_dir}" \
  -ov \
  -format UDZO \
  "${output_dmg}" >&2

# Set the custom icon on the DMG file itself
swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(byReferencingFile: "'"${script_dir}/AppIcon.icns"'"), forFile: "'"${output_dmg}"'", options: [])'

echo "${output_dmg}"
