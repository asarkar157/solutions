package policy

default approval_required := false

# Gate triggering any production pipeline in Jenkins
approval_required if {
	input.tool.name == "cicd_trigger_pipeline"
	pipeline_name := lower(input.tool.arguments.pipeline)
	is_production_pipeline(pipeline_name)
}

is_production_pipeline(name) if contains(name, "prod")

is_production_pipeline(name) if contains(name, "production")

is_production_pipeline(name) if contains(name, "release")
