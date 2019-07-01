# load balancer configuration
# Create instanse group
resource "google_compute_instance_group" "reddit-app" {
  name = "reddit-app"
  description = "Reddip app instanse group"
  zone = "${var.zone}"
  instances = [ "${google_compute_instance.app.self_link}" ]

  named_port {
    name = "http"
    port = "9292"
  }
}

# Create backend for lb
resource "google_compute_backend_service" "reddit-app" {
  name = "reddit backend"
  port_name = "http"
  protocol = "HTTP"

  backend {
    group = "${google_compute_instance_group.reddit-app.self_link}"
  }

  health_checks [
    "${google_compute_https_health_check.reddit-health.self_link}"
  ]
}

# add health check
resource "google_compute_https_health_check" "reddit-health" {
  name = "reddit-health"
  request_path = "/"
  port = "9292"
}
