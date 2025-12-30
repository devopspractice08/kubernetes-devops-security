package main

# 1. Block secrets in ENV
secrets_env = ["passwd", "password", "secret", "key", "token", "apikey"]
deny[msg] {
    input[i].Cmd == "env"
    some j
    val := lower(input[i].Value[j])
    contains(val, secrets_env[_])
    msg := sprintf("Line %d: Potential secret in ENV: %s", [i, val])
}

# 2. Trusted base images (Allowing official and specific libraries)
# Note: Your current rule blocks "eclipse-temurin" because it HAS NO slash. 
# Usually, people block images WITHOUT a slash to ensure they come from a specific registry.
deny[msg] {
    input[i].Cmd == "from"
    val := input[i].Value[0]
    contains(val, "/") # This blocks namespaces. Remove this if you use private registries.
    msg := sprintf("Line %d: Use a trusted base image without namespaces", [i])
}

# 3. No 'latest' tags
deny[msg] {
    input[i].Cmd == "from"
    val := input[i].Value[0]
    contains(val, ":latest")
    msg := sprintf("Line %d: Do not use 'latest' tag", [i])
}

# 4. Must switch from root
any_user {
    input[_].Cmd == "user"
}
deny[msg] {
    not any_user
    msg := "Security Violation: Dockerfile must contain a USER instruction to switch from root"
}

# 5. COPY not ADD
deny[msg] {
    input[i].Cmd == "add"
    msg := sprintf("Line %d: Use COPY instead of ADD", [i])
}
