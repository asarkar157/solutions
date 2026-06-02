# Hard rule — agent persona byte cap (Guild rejects personas > 15000 bytes).
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

resource "terraform_data" "rendered_persona_length_guard" {
  lifecycle {
    precondition {
      condition     = length(local.rendered_architect_persona) <= 15000
      error_message = "Rendered monorepo-split-architect persona exceeds 15000 bytes. Trim personas/monorepo-split-architect.md.tftpl."
    }
  }
}

resource "terraform_data" "rendered_analyst_persona_length_guard" {
  lifecycle {
    precondition {
      condition     = length(local.rendered_analyst_persona) <= 15000
      error_message = "Rendered split-domain-analyst persona exceeds 15000 bytes. Trim personas/split-domain-analyst.md.tftpl."
    }
  }
}
