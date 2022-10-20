module "terra3_environment" {
  source  = "it-objects/terra3/aws"
  version = "0.9.2"

  solution_name = "example-solution"

  create_load_balancer = true
  nat                  = "NAT_INSTANCES" # spawns EC2 instances instead of NAT Gateways for cost savings

  app_components = {
    backend_service = {
      instances = 1

      total_cpu    = 256
      total_memory = 512

      container = [
        module.api_container
      ]

      listener_rule_prio = 200
      path_mapping       = "/api/*"
      service_port       = 80
    }
  }
}

module "api_container" {
  source  = "it-objects/terra3/aws//modules/container"
  version = "0.9.2"

  name = "backend_service"

  container_image  = "nginxdemos/hello"
  container_cpu    = 256
  container_memory = 512

  port_mappings = [{ # container reachable by load balancer must share the same app_component's name and port
    protocol      = "tcp"
    containerPort = 80
  }]
}
