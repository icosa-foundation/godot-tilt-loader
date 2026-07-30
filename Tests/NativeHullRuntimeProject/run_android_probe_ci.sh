#!/usr/bin/env bash
set -euo pipefail

package_name="org.icosa.openbrushhullprobe"
result_file="files/obh_runtime_result.txt"

activity="$(
	adb shell cmd package resolve-activity --brief "$package_name" \
		| tr -d '\r' \
		| tail -n 1
)"
if [[ -z "$activity" || "$activity" == "No activity found" ]]; then
	echo "OBH_ANDROID_CI: launcher activity not found for $package_name" >&2
	exit 1
fi

adb shell am start -n "$activity"
for attempt in $(seq 1 30); do
	if adb shell run-as "$package_name" cat "$result_file" \
		> android-runtime.log 2>/dev/null; then
		break
	fi
	sleep 2
done

adb logcat -d > android-logcat.log
grep -F "OBH_RUNTIME: native_extension_loaded=true ok=true" android-runtime.log
