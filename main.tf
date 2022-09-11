locals {

  name_prefix = lower(var.name_prefix)
  name_suffix = lower(var.name_suffix)

  # Resource Group
  resource_group = "app-grp"
  location = "West Europe"

  # Tags
  default_tags = var.default_tags_enabled ? {
    env   = var.environment
    stack = var.stack
  } : {}

  # Generate a list of queues to create
  queues_list = flatten(
    [for namespace, values in var.servicebus_namespaces_queues :
      [for queuename in keys(lookup(values, "queues", {})) :
        "${namespace}|${queuename}"
      ]
    ]
  )

  # Generate a list of queues to create shared access policies with reader right
  queues_reader = flatten(
    [for namespace, values in var.servicebus_namespaces_queues :
      [for queuename, params in lookup(values, "queues", {}) :
        "${namespace}|${queuename}" if lookup(params, "reader", false)
      ]
    ]
  )

  # Generate a list of queues to create shared access policies with sender right
  queues_sender = flatten(
    [for namespace, values in var.servicebus_namespaces_queues :
      [for queuename, params in lookup(values, "queues", {}) :
        "${namespace}|${queuename}" if lookup(params, "sender", false)
      ]
    ]
  )

  # Generate a list of queues to create shared access policies with manage right
  queues_manage = flatten(
    [for namespace, values in var.servicebus_namespaces_queues :
      [for queuename, params in lookup(values, "queues", {}) :
        "${namespace}|${queuename}" if lookup(params, "manage", false)
      ]
    ]
  )

}


resource "azurerm_resource_group" "servicebus" {
  name     = local.resource_group
  location = local.location
}

resource "azurerm_servicebus_namespace" "servicebus_namespace" {
  for_each            = var.servicebus_namespaces_queues
  name                = lookup(each.value, "custom_name", azurecaf_name.servicebus_namespace[each.key].result)
  resource_group_name      = azurerm_resource_group.servicebus.name
  location                 = azurerm_resource_group.servicebus.location

  sku            = lookup(each.value, "sku", "Basic")
  capacity       = lookup(each.value, "capacity", lookup(each.value, "sku", "Basic") == "Premium" ? 1 : 0)
#  zone_redundant = lookup(each.value, "zone_redundant")

  tags = merge(
    local.default_tags,
    var.extra_tags,
  )
}

resource "azurerm_servicebus_queue_authorization_rule" "reader" {
  for_each = toset(local.queues_reader)
  name     = var.use_caf_naming ? azurecaf_name.servicebus_queue_auth_rule_reader[each.key].result : "${split("|", each.key)[1]}-reader"
  queue_id = azurerm_servicebus_queue.queue[each.key].id

  listen = true
  send   = false
  manage = false
}

resource "azurerm_servicebus_queue_authorization_rule" "sender" {
  for_each = toset(local.queues_sender)
  name     = var.use_caf_naming ? azurecaf_name.servicebus_queue_auth_rule_sender[each.key].result : "${split("|", each.key)[1]}-sender"
  queue_id = azurerm_servicebus_queue.queue[each.key].id

  listen = false
  send   = true
  manage = false
}

resource "azurerm_servicebus_queue_authorization_rule" "manage" {
  for_each = toset(local.queues_manage)
  name     = var.use_caf_naming ? azurecaf_name.servicebus_queue_auth_rule_manage[each.key].result : "${split("|", each.key)[1]}-manage"
  queue_id = azurerm_servicebus_queue.queue[each.key].id

  listen = true
  send   = true
  manage = true
}

resource "azurerm_servicebus_queue" "queue" {
  for_each     = toset(local.queues_list)
  name         = var.use_caf_naming ? azurecaf_name.servicebus_queue[each.key].result : split("|", each.key)[1]
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace[split("|", each.key)[0]].id

  auto_delete_on_idle                     = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "auto_delete_on_idle", null)
  default_message_ttl                     = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "default_message_ttl", null)
  duplicate_detection_history_time_window = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "duplicate_detection_history_time_window", null)
  enable_express                          = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "enable_express", false)
  enable_partitioning                     = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "enable_partitioning", null)
  lock_duration                           = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "lock_duration", null)
  max_size_in_megabytes                   = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "max_size_in_megabytes", null)
  requires_duplicate_detection            = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "requires_duplicate_detection", null)
  requires_session                        = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "requires_session", null)
  dead_lettering_on_message_expiration    = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "dead_lettering_on_message_expiration", null)
  max_delivery_count                      = lookup(var.servicebus_namespaces_queues[split("|", each.key)[0]]["queues"][split("|", each.key)[1]], "max_delivery_count", null)
}

resource "azurecaf_name" "servicebus_namespace" {
  for_each = var.servicebus_namespaces_queues

  name          = var.stack
  resource_type = "azurerm_servicebus_namespace"
  prefixes      = var.name_prefix == "" ? null : [local.name_prefix]
  suffixes      = compact([var.client_name, var.location_short, var.environment, each.key, local.name_suffix, var.use_caf_naming ? "" : "bus"])
  use_slug      = var.use_caf_naming
  clean_input   = true
  separator     = "-"
}

resource "azurecaf_name" "servicebus_queue" {
  for_each = toset(local.queues_list)

  name          = var.stack
  resource_type = "azurerm_servicebus_queue"
  prefixes      = var.name_prefix == "" ? null : [local.name_prefix]
  suffixes      = compact([var.client_name, var.location_short, var.environment, split("|", each.key)[1], local.name_suffix])
  use_slug      = var.use_caf_naming
  clean_input   = true
  separator     = "-"
}

resource "azurecaf_name" "servicebus_queue_auth_rule_reader" {
  for_each = toset(local.queues_reader)

  name          = var.stack
  resource_type = "azurerm_servicebus_queue_authorization_rule"
  prefixes      = var.name_prefix == "" ? null : [local.name_prefix]
  suffixes      = compact([var.client_name, var.location_short, var.environment, each.key, "reader", local.name_suffix])
  use_slug      = var.use_caf_naming
  clean_input   = true
  separator     = "-"
}

resource "azurecaf_name" "servicebus_queue_auth_rule_sender" {
  for_each = toset(local.queues_sender)

  name          = var.stack
  resource_type = "azurerm_servicebus_queue_authorization_rule"
  prefixes      = var.name_prefix == "" ? null : [local.name_prefix]
  suffixes      = compact([var.client_name, var.location_short, var.environment, each.key, "sender", local.name_suffix])
  use_slug      = var.use_caf_naming
  clean_input   = true
  separator     = "-"
}

resource "azurecaf_name" "servicebus_queue_auth_rule_manage" {
  for_each = toset(local.queues_manage)

  name          = var.stack
  resource_type = "azurerm_servicebus_queue_authorization_rule"
  prefixes      = var.name_prefix == "" ? null : [local.name_prefix]
  suffixes      = compact([var.client_name, var.location_short, var.environment, each.key, "manage", local.name_suffix])
  use_slug      = var.use_caf_naming
  clean_input   = true
  separator     = "-"
}
