variable "gateway_mode" {
  type        = string
  default     = "bundled"
  description = <<-DESC
    Controls gateway deployment architecture:
    - "bundled": Deploy full stack including internal APIM Premium gateway (default)
    - "citadel-front": Backend-only mode for external Citadel AI Hub Gateway; skips internal APIM deployment
  DESC

  validation {
    condition     = contains(["bundled", "citadel-front"], var.gateway_mode)
    error_message = "gateway_mode must be 'bundled' or 'citadel-front'."
  }
}
