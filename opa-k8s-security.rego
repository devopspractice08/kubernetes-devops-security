package main

import rego.v1

# 1. Enforce Service type NodePort
deny contains msg if {
    input.kind == "Service"
    input.spec.type != "NodePort"
    msg := sprintf("Service '%s' must be of type NodePort", [input.metadata.name])
}

# 2. Enforce Non-Root for all containers
deny contains msg if {
    input.kind == "Deployment"
    some i
    container := input.spec.template.spec.containers[i]
    
    # Check if securityContext is missing OR runAsNonRoot is not true
    not is_non_root(container)
    
    msg := sprintf("Deployment '%s', container '%s' must have runAsNonRoot: true", [input.metadata.name, container.name])
}

# Helper rule to check for the field
is_non_root(container) if {
    container.securityContext.runAsNonRoot == true
}
