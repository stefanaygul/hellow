module "servicebus" {
  source  =  "../modules/servicebus"


#  resource_group_name = "app-gr"
  location       = "East US"
  location_short = "eastus"
  client_name    = "yunyuy"
  environment    = "dev"
  stack          = "dev"
  resource_group_name = "app-gr"

  servicebus_namespaces_queues = {
    # You can just create a servicebus_namespace
    servicebus0 = {}

    # Or create a servicebus_namespace with some queues with default values
    servicebus1 = {
      queues = {
        queue1 = {}
        queue2 = {}
      }
    }

    # Or customize everything
    servicebus2 = {
      custom_name    = format("%s-%s-%s-custom", "dev", "yunyuy", "eastus")
      sku            = "Standard"
      capacity       = 0
#      zone_redundant = "sku"

      queues = {
        queue100 = {
          reader = true
          sender = true
          manage = true
        }
        queue200 = {
          dead_lettering_on_message_expiration = true
          default_message_ttl                  = "PT10M"
          reader                               = true
        }
        queue300 = {
          duplicate_detection_history_time_window = "PT30M"
          sender                                  = true
        }
        queue400 = {
          requires_duplicate_detection = true
          manage                       = true
        }
      }
    }
  }
}
