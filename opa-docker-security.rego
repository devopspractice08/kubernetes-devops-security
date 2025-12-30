package main

import rego.v1

# 1. Block secrets in ENV keys
secrets_env := ["passwd", "password", "secret", "key", "token", "apikey"]

deny contains msg if {
	input[i].Cmd == "env"
	val := lower(input[i].Value[_])
	some secret in secrets_env
	contains(val, secret)
	msg := sprintf("Line %d: Potential secret in ENV key: %s", [i, input[i].Value])
}

# 2. No 'latest' tags
deny contains msg if {
	input[i].Cmd == "from"
	val := input[i].Value[0]
	contains(val, ":latest")
	msg := sprintf("Line %d: Do not use 'latest' tag for base images", [i])
}

# 3. Avoid curl/wget in RUN
deny contains msg if {
	input[i].Cmd == "run"
	val := lower(concat(" ", input[i].Value))
	regex.match(`(curl|wget)`, val)
	msg := sprintf("Line %d: Avoid curl/wget in RUN", [i])
}

# 4. No system upgrades in RUN
upgrade_cmds := ["apk upgrade", "apt-get upgrade", "dist-upgrade"]
deny contains msg if {
	input[i].Cmd == "run"
	val := lower(concat(" ", input[i].Value))
	some upgrade in upgrade_cmds
	contains(val, upgrade)
	msg := sprintf("Line %d: Do not upgrade system packages in Dockerfile", [i])
}

# 5. COPY not ADD
deny contains msg if {
	input[i].Cmd == "add"
	msg := sprintf("Line %d: Use COPY instead of ADD", [i])
}

# 6. Must switch from root
any_user if {
	input[_].Cmd == "user"
}

deny contains msg if {
	not any_user
	msg := "Use USER to switch from root"
}
