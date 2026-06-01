resource "terraform_data" "persona_length_guard" {
  for_each = fileset("${path.module}/personas", "*.md")

  input = each.value

  lifecycle {
    precondition {
      condition = length(file("${path.module}/personas/${each.value}")) <= 15000
      error_message = format(
        "Persona personas/%s is %d chars; Guild caps at 15000. Trim the file before applying.",
        each.value,
        length(file("${path.module}/personas/${each.value}")),
      )
    }
  }
}
