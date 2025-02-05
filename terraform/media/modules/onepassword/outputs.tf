output "items" {
  description = "Map of item titles to their fields"
  sensitive   = true
  value = {
    for title, item in data.onepassword_item.items : title => merge(
      {
        username = item.username
        password = item.password
      },
      # Create a single map of all fields from all sections
      {
        for field in flatten([
          for section in item.section : section.field
        ]) : field.label => field.type == "CONCEALED" ? sensitive(field.value) : field.value
      }
    )
  }
}
