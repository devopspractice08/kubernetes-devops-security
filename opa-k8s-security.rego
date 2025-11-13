package main

# Rule 1: Service type must be NodePort
deny[msg] {
    input.kind == "Service"
    input.spec.type != "NodePort"
    msg := "Service type should be NodePort"
}

# Rule 2: Deployment containers must not run as root
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.runAsNonRoot != true
    msg := sprintf("Container '%s' must not run as root (runAsNonRoot=true)", [container.name])
}
