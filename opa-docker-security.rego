package main

# -------------------------
# Do Not store secrets in ENV variables
# -------------------------
secrets_env = [
  "passwd",
  "password",
  "pass",
  "secret",
  "key",
  "access",
  "api_key",
  "apikey",
  "token",
  "tkn"
]

deny[msg] {
  input[i].Cmd == "env"
  some j
  val := input[i].Value[j]
  some secret
  secrets_env[_] == lower(val)
  msg = sprintf("Line %d: Potential secret in ENV key found: %s", [i, val])
}

# -------------------------
# Do not use 'latest' tag for base images
# -------------------------
deny[msg] {
  input[i].Cmd == "from"
  val := split(input[i].Value[0], ":")
  count(val) > 1
  lower(val[1]) == "latest"
  msg = sprintf("Line %d: do not use 'latest' tag for base images", [i])
}

# -------------------------
# Avoid curl/wget bashing
# -------------------------
deny[msg] {
  input[i].Cmd == "run"
  val := concat(" ", input[i].Value)
  regex.match("(curl|wget)[^|^>]*[|>]", lower(val))
  msg = sprintf("Line %d: Avoid curl/wget bashing", [i])
}

# -------------------------
# Do not upgrade system packages
# -------------------------
upgrade_commands = [
  "apk upgrade",
  "apt-get upgrade",
  "dist-upgrade"
]

deny[msg] {
  input[i].Cmd == "run"
  val := concat(" ", input[i].Value)
  contains(val, upgrade_commands[_])
  msg = sprintf("Line %d: Do not upgrade your system packages", [i])
}

# -------------------------
# Do not use ADD
# -------------------------
deny[msg] {
  input[i].Cmd == "add"
  msg = sprintf("Line %d: Use COPY instead of ADD", [i])
}

# -------------------------
# Must specify a non-root USER
# -------------------------
forbidden_users = [
  "root",
  "toor",
  "0"
]

deny[msg] {
  input[i].Cmd == "user"
  val := input[i].Value[_]
  forbidden_users[_] == lower(val)
  msg = sprintf("Line %d: Do not run as root: %s", [i, val])
}

deny[msg] {
  not input[_].Cmd == "user"
  msg = "Do not run as root, use USER instead"
}

# -------------------------
# Do not use sudo
# -------------------------
deny[msg] {
  input[i].Cmd == "run"
  val := concat(" ", input[i].Value)
  contains(lower(val), "sudo")
  msg = sprintf("Line %d: Do not use 'sudo' command", [i])
}
