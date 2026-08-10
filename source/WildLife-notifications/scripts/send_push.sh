#!/bin/bash
# to execute it first chmod +x <script_name>.sh

deviceToken="xxx"
authKey="./AuthKey.p8"
authKeyId="xxx"
teamId="xxx"
bundleId="me.dmi3j.push-notification-demo"
endpoint=https://api.development.push.apple.com

read -r -d '' payload <<-'EOF'
{
	"Simulator Target Bundle": "me.dmi3j.push-notification-demo",
	"aps": {
		"alert": {
			"title": "Lorem ipsum title",
			"body": "Lorem ipsum body",
		}
	}
}
EOF

# --------------------------------------------------------------------------

base64() {
    openssl base64 -e -A | tr -- '+/' '-_' | tr -d =
}

sign() {
    printf "$1"| openssl dgst -binary -sha256 -sign "$authKey" | base64
}

time=$(date +%s)
header=$(printf '{ "alg": "ES256", "kid": "%s" }' "$authKeyId" | base64)
claims=$(printf '{ "iss": "%s", "iat": %d }' "$teamId" "$time" | base64)
jwt="$header.$claims.$(sign $header.$claims)"

curl --verbose \
--header "content-type: application/json" \
--header "authorization: bearer $jwt" \
--header "apns-topic: $bundleId" \
--data "$payload" \
$endpoint/3/device/$deviceToken