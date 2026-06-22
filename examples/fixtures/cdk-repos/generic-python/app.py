#!/usr/bin/env python3
import aws_cdk as cdk
from sample_stack.sample_stack import SampleStack

app = cdk.App()
SampleStack(app, "SampleStack")
app.synth()
