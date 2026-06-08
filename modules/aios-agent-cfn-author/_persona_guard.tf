resource "terraform_data" "persona_length_guard" {
  for_each = fileset("${path.module}/personas", "*.md")

  input = each.value

  lifecycle {
    precondition {
      condition = length(filebase64("${path.module}/personas/${each.value}")) <= 20000
      error_message = format(
        "Persona personas/%s exceeds Guild 15000-byte cap (base64 length %d). Trim the file before applying.",
        each.value,
        length(filebase64("${path.module}/personas/${each.value}")),
      )
    }
  }
}
