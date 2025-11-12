package main

# Do not store secrets in ENV variables
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
    some i
    input[i].Cmd == "env"
    val := lower(input[i].Value)
    secret := secrets_env[_]
    contains(val, secret)
    msg = sprintf("Line %d: Potential secret in ENV key found: %s", [i, input[i].Value])
}

# Do not use 'latest' tag for base image
deny[msg] {
    some i
    input[i].Cmd == "from"
    val := split(input[i].Value[0], ":")
    count(val) > 1
    contains(lower(val[1]), "latest")
    msg = sprintf("Line %d: do not use 'latest' tag for base images", [i])
}

# Avoid curl or wget piping to shell
deny[msg] {
    some i
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    matches := regex.find_n("(curl|wget)[^|^>]*[|>]", lower(val), -1)
    count(matches) > 0
    msg = sprintf("Line %d: Avoid curl bashing", [i])
}

# Do not upgrade system packages
upgrade_commands = {
    "apk upgrade",
    "apt-get upgrade",
    "dist-upgrade"
}

deny[msg] {
    some i
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    command := upgrade_commands[_]
    contains(val, command)
    msg = sprintf("Line %d: Do not upgrade your system packages", [i])
}

# Do not use ADD, use COPY
deny[msg] {
    some i
    input[i].Cmd == "add"
    msg = sprintf("Line %d: Use COPY instead of ADD", [i])
}

# Must specify a user
deny[msg] {
    not some i
    input[i].Cmd == "user"
    msg = "Do not run as root, use USER instead"
}

# Do not run as forbidden users
forbidden_users = {
    "root",
    "toor",
    "0"
}

deny[msg] {
    some i
    input[i].Cmd == "user"
    val := lower(input[i].Value)
    forbidden := forbidden_users[_]
    contains(val, forbidden)
    msg = sprintf("Line %d: Do not run as root: %s", [i, input[i].Value])
}

# Do not use sudo
deny[msg] {
    some i
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    contains(lower(val), "sudo")
    msg = sprintf("Line %d: Do not use 'sudo' command", [i])
}
