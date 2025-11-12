package main

# -------------------------
# Do Not store secrets in ENV variables
# -------------------------
secrets_env = {
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
}

deny[msg] {
    input[i].Cmd == "env"
    some j
    secrets_env[secret_key]
    lower(input[i].Value[j]) == secret_key
    msg = sprintf("Line %d: Potential secret in ENV key found: %s", [i, input[i].Value[j]])
}

# -------------------------
# Do not use 'latest' tag for base images
# -------------------------
deny[msg] {
    input[i].Cmd == "from"
    split(input[i].Value[0], ":")[1] == "latest"
    msg = sprintf("Line %d: do not use 'latest' tag for base images", [i])
}

# -------------------------
# Avoid curl/wget bashing
# -------------------------
deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    count(regex.find_n("(curl|wget)[^|^>]*[|>]", lower(val), -1)) > 0
    msg = sprintf("Line %d: Avoid curl/wget bashing", [i])
}

# -------------------------
# Do not upgrade system packages
# -------------------------
upgrade_commands = {
    "apk upgrade",
    "apt-get upgrade",
    "dist-upgrade"
}

deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    upgrade_commands[cmd]
    contains(val, cmd)
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
forbidden_users = {
    "root",
    "toor",
    "0"
}

deny[msg] {
    input[i].Cmd == "user"
    some j
    forbidden_users[forbidden]
    lower(input[i].Value[j]) == forbidden
    msg = sprintf("Line %d: Do not run as root: %s", [i, input[i].Value[j]])
}

# Deny if no USER command exists
deny[msg] {
    count([i | input[i].Cmd == "user"]) == 0
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
