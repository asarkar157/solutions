from aws_cdk import App
from aws_cdk.assertions import Template
from sample_stack.sample_stack import SampleStack


def test_sample_stack_has_versioned_bucket() -> None:
    app = App()
    stack = SampleStack(app, "TestStack")
    template = Template.from_stack(stack)

    template.resource_count_is("AWS::S3::Bucket", 1)
    template.has_resource_properties(
        "AWS::S3::Bucket",
        {
            "VersioningConfiguration": {"Status": "Enabled"},
        },
    )
