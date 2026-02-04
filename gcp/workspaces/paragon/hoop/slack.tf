resource "hoop_plugin_config" "slack" {
  count = local.slack_enabled ? 1 : 0

  plugin_name = "slack"
  config = {
    SLACK_BOT_TOKEN = var.hoop_slack_bot_token
    SLACK_APP_TOKEN = var.hoop_slack_app_token
  }
}

resource "hoop_plugin_connection" "slack" {
  for_each = local.slack_enabled ? local.review_required_connections : {}

  plugin_name   = "slack"
  connection_id = hoop_connection.all_connections[each.key].id
  config        = var.hoop_slack_channel_ids

  depends_on = [hoop_plugin_config.slack]
}
