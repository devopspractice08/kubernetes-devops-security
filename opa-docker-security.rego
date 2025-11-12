package main

# ==========================
# Secrets in ENV variables
# ==========================
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
    val := input[i].Value
    contains(lower(val[_]), secrets_env[_])
    msg = sprintf("Line %d: Potential secret in ENV key found: %s", [i, val])
}

# ==========================
# Avoid 'latest' tag for base images
# ==========================
deny[msg] {
    input[i].Cmd == "from"
    val := split(input[i].Value[0], ":")
    contains(lower(val[1]), "latest")
    msg = sprintf("Line %d: do not use 'latest' tag for base images", [i])
}

# ==========================
# Avoid curl/wget bashing
# ==========================
deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    matches := regex.find_n("(curl|wget)[^|^>]*[|>]", lower(val), -1)
    count(matches) > 0
    msg = sprintf("Line %d: Avoid curl bashing", [i])
}

# ==========================
# Do not upgrade system packages
# ==========================
upgrade_commands = [
    "apk upgrade",
    "apt-get upgrade",
    "dist-upgrade",
]

deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    contains(val, upgrade_commands[_])
    msg = sprintf("Line %d: Do not upgrade your system packages", [i])
}

# ==========================
# Avoid ADD
# ==========================
deny[msg] {
    input[i].Cmd == "add"
    msg = sprintf("Line %d: Use COPY instead of ADD", [i])
}

# ==========================
# Must specify a non-root USER
# ==========================
# Deny if no USER command exists
deny[msg] {
    count([i | input[i].Cmd == "user"]) == 0
    msg = "Do not run as root, use USER instead"
}

# Forbidden users
forbidden_users = [
    "root",
    "toor",
    "0"
]

deny[msg] {
    input[i].Cmd == "user"
    val := input[i].Value
    contains(lower(val[_]), forbidden_users[_])
    msg = sprintf("Line %d: Do not run as root: %s", [i, val])
}

# ==========================
# Do not use sudo
# ==========================
deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    contains(lower(val), "sudo")
    msg = sprintf("Line %d: Do not use 'sudo' command", [i])
}
